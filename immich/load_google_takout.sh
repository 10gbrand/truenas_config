# Balanced performance and reliability
immich-go upload from-google-photos \
  --server=http://localhost:2283 \
  --api-key=your-api-key \
  --concurrent-uploads=8 \
  --manage-raw-jpeg=StackCoverRaw \
  --manage-burst=Stack \
  /path/to/takeout-*.zip