if BACstack.MixProject.sc_enabled?() do
  defmodule BACnet.Stack.Transport.ScTransport.Credentials do
    @moduledoc """
    Prepares and verifies site credentials for BACnet Secure Connect.

    ## Loading local credentials

    Use `from_pem/3` to load an operational certificate, its private key, and
    one or two site issuer certificates. Every certificate PEM must contain
    exactly one X.509 certificate. The operational certificate must match the
    private key, be within its validity interval, and validate directly against
    a configured issuer. During rotation, the two issuer slots let the port
    accept peers using either signing authority.

    The credential struct contains the encoded private key, and inspecting it
    exposes that field. Keep the struct out of logs and diagnostic output.

    ## Authenticating a peer

    `tls/2` configures mutual TLS 1.3 for either connection role. The hub
    requires a client certificate during the handshake. Both roles use OTP's
    TLS certificate verification and additionally validate the peer's
    certificate against a configured direct issuer. Those checks require a
    well-formed certificate that is currently valid. Set `:crl_check` to
    enable OTP revocation checking.

    On the node, `:verify_hostname` enables TLS hostname verification. With
    the default setting, the node disables server name indication and relies
    on the configured issuer for authentication. The peer's BACnet Device
    UUID and VMAC are exchanged independently of its TLS certificate.
    """

    @typedoc """
    Validated operational credentials. The certificate and issuers are DER
    binaries, and the key includes its ASN.1 record name and DER encoding.
    """
    @type t :: %__MODULE__{
            cert: binary(),
            key: {atom(), binary()},
            issuers: [binary()]
          }

    @fields [:cert, :key, :issuers]
    @enforce_keys @fields
    defstruct @fields

    @typep private_key :: :public_key.rsa_private_key() | :public_key.ecdsa_private_key()

    @doc """
    Validates an operational certificate, its PEM private key, and one or two
    site issuer certificates. Returns credentials ready for a node or hub.
    """
    @spec from_pem(binary(), binary(), [binary()]) :: {:ok, t()} | {:error, term()}
    def from_pem(cert, key, issuers) do
      with :ok <- BACnet.Stack.Transport.ScTransport.Config.runtime([:ssl, :x509]),
           {:ok, key} <- parse_key(key) do
        from_key(cert, key, issuers)
      end
    end

    @doc """
    Builds credentials from an already decoded private key. The operational
    certificate must match that key and validate against a configured issuer.
    """
    @spec from_key(binary(), private_key(), [binary()]) :: {:ok, t()} | {:error, atom()}
    def from_key(cert_pem, key, issuer_pems) when length(issuer_pems) in 1..2 do
      with {:ok, cert} <- certificate(cert_pem),
           {:ok, issuers} <- issuer_certificates(issuer_pems),
           true <-
             X509.Certificate.public_key(cert) == X509.PublicKey.derive(key) ||
               {:error, :unknown_certificate_key},
           :ok <- validate_certificate(cert, issuers) do
        {:ok,
         %__MODULE__{
           cert: X509.Certificate.to_der(cert),
           key: {elem(key, 0), X509.PrivateKey.to_der(key)},
           issuers: Enum.map(issuers, &X509.Certificate.to_der/1)
         }}
      end
    end

    def from_key(_cert, _key, _issuers), do: {:error, :certificate_invalid}

    @doc """
    Decodes a PEM private key for use in TLS or certificate provisioning.
    """
    @spec parse_key(binary()) :: {:ok, private_key()} | {:error, :unknown_certificate_key}
    def parse_key(pem) do
      case X509.PrivateKey.from_pem(pem) do
        {:ok, key} -> {:ok, key}
        {:error, _reason} -> {:error, :unknown_certificate_key}
      end
    end

    @doc """
    Decodes a PEM file containing exactly one X.509 certificate into its OTP representation.
    """
    @spec certificate(term()) :: {:ok, :public_key.cert()} | {:error, :certificate_malformed}
    def certificate(pem) when is_binary(pem) do
      case :public_key.pem_decode(pem) do
        [{:Certificate, der, :not_encrypted}] ->
          {:ok, :public_key.pkix_decode_cert(der, :otp)}

        _other ->
          {:error, :certificate_malformed}
      end
    rescue
      _error -> {:error, :certificate_malformed}
    end

    def certificate(_pem), do: {:error, :certificate_malformed}

    @doc """
    Builds mutual TLS options for the client or server side of a BACnet/SC
    connection. A node can enable hostname verification in its configuration.
    """
    @spec tls(%{required(:credentials) => t(), optional(atom()) => term()}, :client | :server) ::
            Keyword.t()
    def tls(%{credentials: %{cert: cert, key: key, issuers: issuers}} = config, role) do
      decoded_issuers = Enum.map(issuers, &:public_key.pkix_decode_cert(&1, :otp))

      options = [
        versions: [:"tlsv1.3"],
        verify: :verify_peer,
        cacerts: issuers,
        cert: cert,
        key: key,
        depth: 0,
        verify_fun: {&verify/3, decoded_issuers},
        crl_check: Map.get(config, :crl_check, false),
        partial_chain: fn chain -> trust_issuer(chain, issuers) end
      ]

      case role do
        :server ->
          [{:alpn_preferred_protocols, ["http/1.1"]}, {:fail_if_no_peer_cert, true} | options]

        :client ->
          if config[:verify_hostname] do
            options
          else
            [{:server_name_indication, :disable} | options]
          end
      end
    end

    @spec trust_issuer([binary()], [binary()]) :: {:trusted_ca, binary()} | :unknown_ca
    defp trust_issuer(chain, issuers) do
      case Enum.find(chain, &(&1 in issuers)) do
        nil -> :unknown_ca
        issuer -> {:trusted_ca, issuer}
      end
    end

    @spec issuer_certificates([binary()]) ::
            {:ok, [:public_key.cert()]} | {:error, :certificate_malformed}
    defp issuer_certificates(pems) do
      Enum.reduce_while(pems, {:ok, []}, fn pem, {:ok, certs} ->
        case certificate(pem) do
          {:ok, cert} -> {:cont, {:ok, [cert | certs]}}
          error -> {:halt, error}
        end
      end)
    end

    @spec verify(:public_key.cert(), term(), [:public_key.cert()]) ::
            {:valid | :unknown, [:public_key.cert()]} | {:fail, term()}
    defp verify(_cert, {:bad_cert, reason}, _issuers), do: {:fail, reason}
    defp verify(_cert, {:extension, _extension}, issuers), do: {:unknown, issuers}
    defp verify(_cert, :valid, issuers), do: {:valid, issuers}

    defp verify(cert, :valid_peer, issuers) do
      case validate_certificate(cert, issuers) do
        :ok -> {:valid, issuers}
        {:error, reason} -> {:fail, reason}
      end
    end

    @spec validate_certificate(:public_key.cert(), [:public_key.cert()]) ::
            :ok | {:error, :certificate_invalid | :certificate_expired}
    defp validate_certificate(cert, issuers) do
      Enum.reduce_while(issuers, {:error, :certificate_invalid}, fn issuer, previous ->
        if cert != issuer and :public_key.pkix_is_issuer(cert, issuer) do
          case :public_key.pkix_path_validation(issuer, [cert], []) do
            {:ok, _path} -> {:halt, :ok}
            {:error, {:bad_cert, :cert_expired}} -> {:cont, {:error, :certificate_expired}}
            {:error, _reason} -> {:cont, previous}
          end
        else
          {:cont, previous}
        end
      end)
    end
  end
end
