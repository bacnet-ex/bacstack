[
  # Cause is not consolidating protocols in :dev environment
  ~r/unknown_function.*__impl__.*/,
  # These functions raise and Dialyzer in OTP29 complains about that (Dialyzer resolves to `none()` return type)
  {"lib/bacnet/protocol/apdu/abort.ex",
   "Invalid type specification for function encode_segmented."},
  {"lib/bacnet/protocol/apdu/abort.ex",
   "Invalid type specification for function encode_to_segmented."},
  {"lib/bacnet/protocol/apdu/error.ex",
   "Invalid type specification for function encode_segmented."},
  {"lib/bacnet/protocol/apdu/error.ex",
   "Invalid type specification for function encode_to_segmented."},
  {"lib/bacnet/protocol/apdu/reject.ex",
   "Invalid type specification for function encode_segmented."},
  {"lib/bacnet/protocol/apdu/reject.ex",
   "Invalid type specification for function encode_to_segmented."},
  {"lib/bacnet/protocol/apdu/segment_ack.ex",
   "Invalid type specification for function encode_segmented."},
  {"lib/bacnet/protocol/apdu/segment_ack.ex",
   "Invalid type specification for function encode_to_segmented."},
  {"lib/bacnet/protocol/apdu/simple_ack.ex",
   "Invalid type specification for function encode_segmented."},
  {"lib/bacnet/protocol/apdu/simple_ack.ex",
   "Invalid type specification for function encode_to_segmented."},
  {"lib/bacnet/protocol/apdu/unconfirmed_service_request.ex",
   "Invalid type specification for function encode_segmented."},
  {"lib/bacnet/protocol/apdu/unconfirmed_service_request.ex",
   "Invalid type specification for function encode_to_segmented."}
]
