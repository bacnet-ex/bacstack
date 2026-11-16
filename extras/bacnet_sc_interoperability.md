<!--t:BACnet/SC Interoperability Test Record-->

# BACnet/SC Interoperability Test Record

On 12 November 2026, Rusty BACnet 0.15.0 acted as the client and failover
hub on the same host as the BACstack primary hub and managed node.
Peers used mutual TLS 1.3 and operational certificates from a shared test
CA. The client discovered the device, read its Device and Network Port
properties, and renewed its certificate. Discovery and reads succeeded
via the primary, the failover hub, and the restored primary.

The run did not exercise a second physical host, direct connections, CRL
handling, IPv6, or a separate test with BACstack only in the node role and
all other participants supplied by the third-party implementation.
