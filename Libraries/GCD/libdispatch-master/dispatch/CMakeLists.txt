
set (public_headers
  base.h
  data.h
  dispatch.h
  group.h
  io.h
  object.h
  once.h
  queue.h
  semaphore.h
  source.h
  time.h
)

install(FILES ${public_headers}
  DESTINATION "${DISPATCH_INCLUDE_DIR}/dispatch"
)