if Code.ensure_loaded?(Circuits.UART) do
  defmodule BACnet.Stack.Transport.MstpTransport.EncodingTools do
    @moduledoc false
    # This module contains functions to help with MS/TP encoding and decoding.
    # CRC calculation & COBS De- & Encoding

    @cobs_mask 0x55
    @cobs_crc32k_initial_value 0xFFFFFFFF
    @cobs_crc32k_residue 0x0843323B
    @cobs_adj_for_enc_crc 5

    @doc """
    Calculates the CRC of the given header.

    This function implements the CRC function of the BACnet standard Clause G.1.1.
    """
    @spec calculate_header_crc(iodata() | binary() | byte(), non_neg_integer()) ::
            non_neg_integer()
    def calculate_header_crc(header, crc \\ 0xFF)

    def calculate_header_crc([], crc) do
      crc
    end

    # Handle improper lists
    def calculate_header_crc([head | tail], crc) when not is_list(tail) do
      calculate_header_crc([head, tail | []], crc)
    end

    def calculate_header_crc([byte | tail], crc) when is_list(tail) do
      calculate_header_crc(tail, calculate_header_crc(byte, crc))
    end

    def calculate_header_crc(byte, crc) when is_integer(byte) and byte >= 0 and byte <= 255 do
      crc1 = Bitwise.bxor(crc, byte)

      crc2 =
        for i <- 1..7, reduce: crc1 do
          acc -> Bitwise.bxor(acc, Bitwise.bsl(crc1, i))
        end

      Bitwise.bxor(
        Bitwise.band(crc2, 0xFE),
        Bitwise.band(Bitwise.bsr(crc2, 8), 1)
      )
    end

    def calculate_header_crc(<<>>, crc) do
      crc
    end

    def calculate_header_crc(<<byte, rest::binary>>, crc) do
      calculate_header_crc(rest, calculate_header_crc(byte, crc))
    end

    @doc """
    Calculates the data CRC of the given data.

    This function implements the CRC function of the BACnet standard Clause G.1.2.
    """
    @spec calculate_data_crc(iodata() | binary() | byte(), non_neg_integer()) :: non_neg_integer()
    def calculate_data_crc(data, crc \\ 0xFFFF)

    def calculate_data_crc([], crc) do
      crc
    end

    # Handle improper lists
    def calculate_data_crc([head | tail], crc) when not is_list(tail) do
      calculate_data_crc([head, tail | []], crc)
    end

    def calculate_data_crc([byte | tail], crc) when is_list(tail) do
      calculate_data_crc(tail, calculate_data_crc(byte, crc))
    end

    def calculate_data_crc(byte, crc) when is_integer(byte) and byte >= 0 and byte <= 255 do
      crc_low =
        crc
        |> Bitwise.band(0xFF)
        |> Bitwise.bxor(byte)

      crc
      |> Bitwise.bsr(8)
      |> Bitwise.bxor(Bitwise.bsl(crc_low, 8))
      |> Bitwise.bxor(Bitwise.bsl(crc_low, 3))
      |> Bitwise.bxor(Bitwise.bsl(crc_low, 12))
      |> Bitwise.bxor(Bitwise.bsr(crc_low, 4))
      |> Bitwise.bxor(Bitwise.band(crc_low, 0x0F))
      |> Bitwise.bxor(Bitwise.bsl(Bitwise.band(crc_low, 0x0F), 7))
      # .band(0xFFFF) to limit the values to 16bit... otherwise CRC is wrong
      |> Bitwise.band(0xFFFF)
    end

    def calculate_data_crc(<<>>, crc) do
      crc
    end

    def calculate_data_crc(<<byte, rest::binary>>, crc) do
      calculate_data_crc(rest, calculate_data_crc(byte, crc))
    end

    @doc """
    Performs COBS decoding as per ASHRAE 135 Clause 9.10 and Annex T.

    The iodata will be converted to a binary for simplicity.
    We may revise this in the future.

    This function implements the COBS decoding of the BACnet standard Clause T.2.
    """
    @spec decode_cobs(iodata()) :: {:ok, iodata()} | {:error, term()}
    def decode_cobs(data) do
      data_bin = IO.iodata_to_binary(data)
      data_length = byte_size(data_bin) - @cobs_adj_for_enc_crc

      case cobs_do_decode(data_bin, nil, nil, [], [], data_length, @cobs_crc32k_initial_value) do
        {:ok, _data} = data ->
          data

        {:error, _reason} = err ->
          err
          # {:error, reason, _data, _length, _crc32k} -> {:error, reason}
      end
    end

    # Generic implementation of finishing up the COBS encoding (so that we can support binaries and iolist)
    @spec cobs_do_decode_finish(
            byte(),
            binary(),
            non_neg_integer(),
            list(),
            list(),
            non_neg_integer()
          ) :: {:ok, iodata()} | {:error, term()}
    defp cobs_do_decode_finish(crc_code, crc_data, crc_data_length, first_acc, result_acc, crc32k) do
      # CRC 32K length should always be 4
      crc_length = Bitwise.bxor(crc_code, @cobs_mask) - 1

      if crc_length == 4 and crc_data_length == crc_length do
        expected_crc =
          for <<byte <- crc_data>>, reduce: crc32k do
            acc -> calc_crc32k(Bitwise.bxor(byte, @cobs_mask), acc)
          end

        if expected_crc == @cobs_crc32k_residue do
          {:ok, Enum.reverse(List.flatten([first_acc | result_acc]))}
        else
          {:error, :crc32k_mismatch}
        end
      else
        {:error, :invalid_crc32k_length}
      end
    end

    # Does the COBS decoding
    # It uses first_acc to accumulate each subsequent COBS block,
    # once it encounters the end of the COBS block, it will be pushed into result_acc
    # Both lists are built in reverse and are reversed before returning
    @spec cobs_do_decode(
            binary(),
            byte() | nil,
            byte() | nil,
            list(),
            list(),
            non_neg_integer(),
            non_neg_integer()
          ) ::
            {:ok, iodata()}
            | {:error, term()}
            | {:error, term(), acc :: iodata(), remaining_length :: non_neg_integer(),
               crc32k :: non_neg_integer()}
    defp cobs_do_decode(data, code, previous_code, first_acc, result_acc, data_length, crc32k)

    # defp cobs_do_decode(<<>>, _code, _previous_code, first_acc, result_acc, data_length, crc32k) do
    #   {:error, :unexpected_eof, [first_acc | result_acc], data_length, crc32k}
    # end

    # -- Itering iolists is just too much work and doesn't work with the current code --
    # defp cobs_do_decode([], _code, _previous_code, first_acc, result_acc, data_length, crc32k) do
    #   {:error, :unexpected_eof, [first_acc | result_acc], data_length, crc32k}
    # end

    defp cobs_do_decode(
           <<crc_code, crc_data::binary>>,
           _code,
           _previous_code,
           first_acc,
           result_acc,
           data_length,
           crc32k
         )
         when data_length <= 0 do
      cobs_do_decode_finish(
        crc_code,
        crc_data,
        byte_size(crc_data),
        first_acc,
        result_acc,
        crc32k
      )
    end

    # -- Itering iolists is just too much work and doesn't work with the current code --
    # defp cobs_do_decode(
    #        [crc_code | crc_data],
    #        _code,
    #        _previous_code,
    #        first_acc,
    #        result_acc,
    #        data_length,
    #        crc32k
    #      )
    #      when data_length <= 0 do
    #   new_data = IO.iodata_to_binary(crc_data)
    #   cobs_do_decode_finish(crc_code, new_data, byte_size(new_data), first_acc, result_acc, crc32k)
    # end

    defp cobs_do_decode(data, 0, previous_code, first_acc, result_acc, data_length, crc32k) do
      acc =
        if previous_code == 0xFF do
          first_acc
        else
          [0 | first_acc]
        end

      cobs_do_decode(data, nil, nil, [], [acc | result_acc], data_length, crc32k)
    end

    defp cobs_do_decode(
           <<byte, rest::binary>>,
           code,
           previous_code,
           first_acc,
           result_acc,
           data_length,
           crc32k
         ) do
      cobs_do_decode(
        byte,
        rest,
        code,
        previous_code,
        first_acc,
        result_acc,
        data_length,
        crc32k
      )
    end

    # -- Itering iolists is just too much work and doesn't work with the current code --
    # defp cobs_do_decode(
    #        [byte | rest],
    #        code,
    #        previous_code,
    #        first_acc,
    #        result_acc,
    #        data_length,
    #        crc32k
    #      )
    #      when not is_list(byte) and is_list(rest) do
    #   cobs_do_decode(
    #     byte,
    #     rest,
    #     code,
    #     previous_code,
    #     first_acc,
    #     result_acc,
    #     data_length,
    #     crc32k
    #   )
    # end

    # -- Itering iolists is just too much work and doesn't work with the current code --
    # defp cobs_do_decode(
    #        [[] | rest],
    #        code,
    #        previous_code,
    #        first_acc,
    #        result_acc,
    #        data_length,
    #        crc32k
    #      )
    #      when is_list(rest) do
    #   cobs_do_decode(
    #     rest,
    #     code,
    #     previous_code,
    #     first_acc,
    #     result_acc,
    #     data_length,
    #     crc32k
    #   )
    # end

    # -- Itering iolists is just too much work and doesn't work with the current code --
    # defp cobs_do_decode(
    #        [sublist | rest],
    #        code,
    #        previous_code,
    #        first_acc,
    #        result_acc,
    #        data_length,
    #        crc32k
    #      )
    #      when is_list(sublist) and is_list(rest) do
    #   with {:error, _reason, acc, new_data_length, new_crc32k} <-
    #          cobs_do_decode(sublist, nil, nil, [], [], data_length, crc32k) do
    #     cobs_do_decode(
    #       rest,
    #       code,
    #       previous_code,
    #       [acc | first_acc],
    #       result_acc,
    #       new_data_length,
    #       new_crc32k
    #     )
    #   end
    # end

    # Generic implementation so that we can support binaries and iolist
    @spec cobs_do_decode(
            byte(),
            term(),
            byte() | nil,
            byte() | nil,
            list(),
            list(),
            non_neg_integer(),
            non_neg_integer()
          ) :: {:ok, iodata()} | {:error, term()}
    defp cobs_do_decode(
           code,
           rest,
           nil,
           _previous_code,
           first_acc,
           result_acc,
           data_length,
           crc32k
         ) do
      basic_code = Bitwise.bxor(code, @cobs_mask)

      cobs_do_decode(
        rest,
        basic_code - 1,
        basic_code,
        first_acc,
        result_acc,
        data_length - 1,
        calc_crc32k(code, crc32k)
      )
    end

    defp cobs_do_decode(
           byte,
           rest,
           code,
           previous_code,
           first_acc,
           result_acc,
           data_length,
           crc32k
         ) do
      value = Bitwise.bxor(byte, @cobs_mask)

      cobs_do_decode(
        rest,
        code - 1,
        previous_code,
        [value | first_acc],
        result_acc,
        data_length - 1,
        calc_crc32k(byte, crc32k)
      )
    end

    @doc """
    Performs COBS encoding as per ASHRAE 135 Clause 9.10 and Annex T.

    The iodata will be converted to a binary for simplicity.
    We may revise this in the future.

    This function implements the COBS encoding of the BACnet standard Clause T.1.
    """
    @spec encode_cobs(iodata()) :: {:ok, data :: iodata()}
    def encode_cobs(data) do
      bin_data = IO.iodata_to_binary(data)

      # CRC32K calculation during encoding is not possible - see calc_crc32k_encoding/2 comment
      with {:ok, encoded, _crc32k} <- cobs_do_encode_first(bin_data),
           encoded_bytes = Enum.reverse(List.flatten(encoded)),
           crc32k = Enum.reduce(encoded_bytes, @cobs_crc32k_initial_value, &calc_crc32k/2),
           crc32k = Bitwise.band(Bitwise.bnot(crc32k), @cobs_crc32k_initial_value),
           {:ok, encoded_crc32k, _crc} <-
             cobs_do_encode_first(<<crc32k::size(32)-little>>) do
        {:ok, Enum.reverse(List.flatten([encoded_crc32k | encoded]))}
      end
    end

    # defp cobs_do_encode_first(data) when is_list(data) do
    #   Enum.reduce_while(data, {:ok, [], @cobs_crc32k_initial_value}, fn bin, {:ok, acc, crc32k} ->
    #     case cobs_do_encode(bin, 1, 1, [], [], crc32k) do
    #       {:ok, encoded, new_crc32k} ->
    #         {:cont, {:ok, [encoded | acc], new_crc32k}}

    #       {:error, _err} = err ->
    #         {:halt, err}

    #       _other ->
    #         {:error, :invalid_cobs_encoding}
    #     end
    #   end)
    # end

    defp cobs_do_encode_first(data) when is_binary(data) do
      cobs_do_encode(data, 1, 1, [], [], @cobs_crc32k_initial_value)
    end

    @spec cobs_do_encode(iodata(), 1..255, 0..255, [byte()], iolist(), non_neg_integer()) ::
            {:ok, cobs :: iodata(), crc32k :: non_neg_integer()} | {:error, term()}
    defp cobs_do_encode(data, code, previous_code, acc, final_acc, crc32k)

    defp cobs_do_encode(<<>>, code, _previous_code, acc, final_acc, crc32k) do
      value = Bitwise.bxor(code, @cobs_mask)
      {:ok, [acc, value | final_acc], calc_crc32k_encoding(value, crc32k)}
    end

    # defp cobs_do_encode([], code, _previous_code, acc, final_acc, crc32k) do
    #   value = Bitwise.bxor(code, @cobs_mask)
    #   {:ok, [acc, value | final_acc], calc_crc32k_encoding(value, crc32k)}
    # end

    defp cobs_do_encode(data, 255 = code, _previous_code, acc, final_acc, crc32k) do
      value = Bitwise.bxor(code, @cobs_mask)

      cobs_do_encode(
        data,
        1,
        code,
        [],
        [acc, value | final_acc],
        calc_crc32k_encoding(value, crc32k)
      )
    end

    defp cobs_do_encode(<<0, data::binary>>, code, previous_code, acc, final_acc, crc32k) do
      value = Bitwise.bxor(code, @cobs_mask)

      cobs_do_encode(
        data,
        1,
        previous_code,
        [],
        [acc, value | final_acc],
        calc_crc32k_encoding(value, crc32k)
      )
    end

    defp cobs_do_encode(<<byte, data::binary>>, code, previous_code, acc, final_acc, crc32k) do
      value = Bitwise.bxor(byte, @cobs_mask)

      cobs_do_encode(
        data,
        code + 1,
        previous_code,
        [value | acc],
        final_acc,
        calc_crc32k_encoding(value, crc32k)
      )
    end

    # defp cobs_do_encode([0 | data], code, previous_code, acc, final_acc, crc32k) do
    #   value = Bitwise.bxor(code, @cobs_mask)

    #   cobs_do_encode(
    #     data,
    #     1,
    #     previous_code,
    #     [],
    #     [acc, value | final_acc],
    #     calc_crc32k_encoding(value, crc32k)
    #   )
    # end

    # defp cobs_do_encode([[] | data], code, previous_code, acc, final_acc, crc32k) do
    #   cobs_do_encode(data, code, previous_code, acc, final_acc, crc32k)
    # end

    # defp cobs_do_encode([sublist | data], code, previous_code, acc, final_acc, crc32k)
    #      when is_list(sublist) do
    #   case cobs_do_encode(sublist, code, previous_code, acc, [], crc32k) do
    #     {:ok, encoded, new_crc32k} ->
    #       cobs_do_encode(
    #         data,
    #         1,
    #         1,
    #         [],
    #         [encoded | final_acc],
    #         new_crc32k
    #       )

    #       # other ->
    #       #   other
    #   end
    # end

    # defp cobs_do_encode([byte | data], code, previous_code, acc, final_acc, crc32k) do
    #   value = Bitwise.bxor(byte, @cobs_mask)

    #   cobs_do_encode(
    #     data,
    #     code + 1,
    #     previous_code,
    #     [value | acc],
    #     final_acc,
    #     calc_crc32k_encoding(value, crc32k)
    #   )
    # end

    # defp cobs_do_encode(byte, code, previous_code, acc, final_acc, crc32k)
    #      when is_integer(byte) and byte >= 0 and byte <= 255 do
    #   value = Bitwise.bxor(byte, @cobs_mask)

    #   cobs_do_encode(
    #     [],
    #     code + 1,
    #     previous_code,
    #     [value | acc],
    #     final_acc,
    #     calc_crc32k_encoding(value, crc32k)
    #   )
    # end

    # Calculates the CRC32K value of the given byte (the CRC value should be 32bit).
    # This is the C function from the BACnet specification Clause G.3.1:
    # /* Accumulate "dataValue" into the CRC in "crc32kValue".
    #  * Return value is updated CRC.
    #  *
    #  * Assumes that "uint8_t" is equivalent to one octet.
    #  * Assumes that "uint32_t" is four octets.
    #  * The ^ operator means exclusive OR.
    #  */
    # uint32_t CalcCRC32K(uint8_t dataValue, uint32_t crc32kValue) {
    #   uint8_t data, b;
    #   uint32_t crc;
    #   data = dataValue;
    #   crc  = crc32kValue;
    #   for (b = 0; b < 8; b++) {
    #     if ((data & 1) ^ (crc & 1)) {
    #       crc >>= 1;
    #       crc ^= 0xEB31D82E; /* CRC-32K polynomial, 1 + x**1 + ... + x**30 (+ x**32) */
    #     } else {
    #       crc >>= 1;
    #     }
    #     data >>= 1;
    #   }
    #   return crc;  /* Return updated crc value */
    # }
    @spec calc_crc32k(byte(), non_neg_integer()) :: integer()
    defp calc_crc32k(data, crc)
         when is_integer(data) and data >= 0 and data <= 255 and is_integer(crc) do
      do_calc_crc32k(data, crc, 0)
    end

    # We can't do any CRC32K calculation during encoding,
    # because the order of the bytes are not correct.
    # First the data gets CRC'd and only then the "code",
    # which is incorrect. Thus, for now we simply do no calculation.
    # We may want to revise in the future, so we'll leave it here.
    @compile {:inline, calc_crc32k_encoding: 2}
    defp calc_crc32k_encoding(_data, crc), do: crc

    defp do_calc_crc32k(_data, crc, 8), do: crc

    defp do_calc_crc32k(data, crc, index) do
      new_crc =
        if Bitwise.bxor(Bitwise.band(data, 1), Bitwise.band(crc, 1)) != 0 do
          crc
          |> Bitwise.bsr(1)
          |> Bitwise.bxor(0xEB31D82E)
        else
          Bitwise.bsr(crc, 1)
        end

      do_calc_crc32k(Bitwise.bsr(data, 1), new_crc, index + 1)
    end
  end
end
