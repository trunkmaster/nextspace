#import "OSEBusConnection.h"
#import "OSEBusService.h"

#import "OSEBusMessage.h"

#pragma mark - Decoding from D-Bus

// Is not recursive
static id getBasicType(DBusMessageIter *iter)
{
  int type = dbus_message_iter_get_arg_type(iter);
  id result = nil;

  if (type == DBUS_TYPE_INVALID) {
    return result;
  }

  switch (type) {
    case DBUS_TYPE_STRING: {
      char *val;
      dbus_message_iter_get_basic(iter, &val);
      result = [NSString stringWithCString:val];
    } break;
    case DBUS_TYPE_BYTE: {
      unsigned char val;
      dbus_message_iter_get_basic(iter, &val);
      result = [NSString stringWithFormat:@"%c", val];
    } break;
    case DBUS_TYPE_SIGNATURE: {
      char *val;
      dbus_message_iter_get_basic(iter, &val);
      result = [NSString stringWithCString:val];
    } break;
    case DBUS_TYPE_OBJECT_PATH: {
      char *val;
      dbus_message_iter_get_basic(iter, &val);
      result = [NSString stringWithCString:val];
    } break;
    case DBUS_TYPE_INT16: {
      dbus_int16_t val;
      dbus_message_iter_get_basic(iter, &val);
      result = [NSNumber numberWithInt:val];
    } break;
    case DBUS_TYPE_UINT16: {
      dbus_uint16_t val;
      dbus_message_iter_get_basic(iter, &val);
      result = [NSNumber numberWithUnsignedInt:val];
    } break;
    case DBUS_TYPE_INT32: {
      dbus_int32_t val;
      dbus_message_iter_get_basic(iter, &val);
      result = [NSNumber numberWithInt:val];
    } break;
    case DBUS_TYPE_UINT32: {
      dbus_uint32_t val;
      dbus_message_iter_get_basic(iter, &val);
      result = [NSNumber numberWithUnsignedInt:val];
    } break;
    case DBUS_TYPE_INT64: {
      dbus_int64_t val;
      dbus_message_iter_get_basic(iter, &val);
      result = [NSNumber numberWithUnsignedInt:val];
    } break;
    case DBUS_TYPE_UINT64: {
      dbus_uint64_t val;
      dbus_message_iter_get_basic(iter, &val);
      result = [NSNumber numberWithUnsignedInt:val];
    } break;
    case DBUS_TYPE_DOUBLE: {
      double val;
      dbus_message_iter_get_basic(iter, &val);
      result = [NSNumber numberWithDouble:val];
    } break;
    case DBUS_TYPE_BOOLEAN: {
      dbus_bool_t val;
      dbus_message_iter_get_basic(iter, &val);
      // printf("boolean : %u\n", val);
      result = [NSNumber numberWithUnsignedInt:val];
    } break;
  }

  return result;
}

// Is recursive. `result` have to be set at the first call to this function.
static id decodeDBusMessage(DBusMessageIter *iter, id result)
{
  do {
    int type = dbus_message_iter_get_arg_type(iter);
    id basicResult;
    DBusMessageIter subiter;
    id subiterResult;

    if (type == DBUS_TYPE_INVALID) {
      break;
    }

    /*
     * Basic types
     */
    if ((basicResult = getBasicType(iter)) != nil) {
      if (result != nil) {
        [result addObject:basicResult];
      } else {
        result = basicResult;
        break;
      }
      continue;
    }

    /*
     * Container types
     */
    if (type == DBUS_TYPE_VARIANT) {
      dbus_message_iter_recurse(iter, &subiter);
      subiterResult = decodeDBusMessage(&subiter, nil);
      if (result != nil) {
        [result addObject:subiterResult];
      } else {
        result = subiterResult;
      }
      break;
    } else if (type == DBUS_TYPE_ARRAY || type == DBUS_TYPE_STRUCT) {
      BOOL isBytesArray = NO;
      id object;

      // printf("array\n");

      dbus_message_iter_recurse(iter, &subiter);
      if (dbus_message_iter_get_arg_type(&subiter) == DBUS_TYPE_BYTE) {
        subiterResult = [NSMutableString string];
        isBytesArray = YES;
      } else {
        subiterResult = [NSMutableArray array];
      }
      while (dbus_message_iter_get_arg_type(&subiter) != DBUS_TYPE_INVALID) {
        object = decodeDBusMessage(&subiter, nil);
        if (object) {
          if (isBytesArray != NO) {
            if ([object isEqualToString:@"\000"] == NO) {
              [subiterResult appendString:object];
            }
          } else {
            [subiterResult addObject:object];
          }
        }
        dbus_message_iter_next(&subiter);
      }

      if (result != nil) {
        [result addObject:subiterResult];
      } else {
        result = subiterResult;
        break;
      }
    } else if (type == DBUS_TYPE_DICT_ENTRY) {
      id key, object;

      // printf("dict_entry\n");

      dbus_message_iter_recurse(iter, &subiter);
      key = getBasicType(&subiter);
      dbus_message_iter_next(&subiter);
      object = decodeDBusMessage(&subiter, nil);
      result = @{key : object};

      break;
    } else {
      NSLog(@"BusKit error: unknown D-Bus data type '%c'", type);
    }
  } while (dbus_message_iter_next(iter));

  return result;
}

#pragma mark - Encoding to D-Bus wire format (marshalling)

static dbus_bool_t append_arg(DBusMessageIter *iter, NSArray *arguments, const char *dbus_signature);
static dbus_bool_t append_array(DBusMessageIter *master_iterator, NSArray *elements,
                                const char *signature);
static dbus_bool_t append_struct(DBusMessageIter *master_iterator, NSArray *elements,
                                 const char *signature);

static void handle_oom(dbus_bool_t success)
{
  if (!success) {
    NSException *exception;
    exception = [NSException exceptionWithName:@"BKMessage: OOM"
                                        reason:@"Ran out of memory"
                                      userInfo:nil];
    [exception raise];
  }
}
static dbus_bool_t append_array(DBusMessageIter *master_iterator, NSArray *elements,
                                const char *signature)
{
  DBusMessageIter array_iterator;
  dbus_bool_t ret = false;
  char elements_type = signature[0];

  // open container with sub-iterator
  char dbus_signature[2];
  dbus_signature[0] = elements_type;
  dbus_signature[1] = '\0';
  ret = dbus_message_iter_open_container(master_iterator, DBUS_TYPE_ARRAY, dbus_signature,
                                         &array_iterator);
  handle_oom(ret);

  for (id value in elements) {
    printf("append_array of element type: %c\n", elements_type);
    ret = append_arg(&array_iterator, value, signature);
  }

  // close sub-iterator
  ret = dbus_message_iter_close_container(master_iterator, &array_iterator);

  return ret;
}
// signature must point to the first element type of structure
static dbus_bool_t append_struct(DBusMessageIter *master_iterator, NSArray *elements,
                                 const char *signature)
{
  DBusMessageIter struct_iterator;
  dbus_bool_t ret = false;

  ret = dbus_message_iter_open_container(master_iterator, DBUS_TYPE_STRUCT, NULL, &struct_iterator);
  handle_oom(ret);

  for (int i = 0; signature[0] != DBUS_STRUCT_END_CHAR; i++) {
    printf("append_struct of element type: %c\n", signature[0]);
    ret = append_arg(&struct_iterator, elements[i], signature);
    signature++;
  }
  signature++;

  // close sub-iterator
  ret = dbus_message_iter_close_container(master_iterator, &struct_iterator);

  return ret;
}
static dbus_bool_t append_arg(DBusMessageIter *iter, id argument, const char *dbus_signature)
{
  const char *value = NULL;
  dbus_bool_t ret;

  if ([argument isKindOfClass:[NSString class]]) {
    value = [argument cString];
  } else if ([argument isKindOfClass:[NSNumber class]]) {
    value = [[argument stringValue] cString];
  }

  switch (dbus_signature[0]) {
    case DBUS_TYPE_BYTE: {
      unsigned char byte = strtoul(value, NULL, 0);
      ret = dbus_message_iter_append_basic(iter, DBUS_TYPE_BYTE, &byte);
    } break;
    case DBUS_TYPE_DOUBLE: {
      // printf("append_arg DOUBLE: %s\n", value);
      double d = strtod(value, NULL);
      ret = dbus_message_iter_append_basic(iter, DBUS_TYPE_DOUBLE, &d);
    } break;
    case DBUS_TYPE_INT16: {
      dbus_int16_t int16 = strtol(value, NULL, 0);
      ret = dbus_message_iter_append_basic(iter, DBUS_TYPE_INT16, &int16);
    } break;
    case DBUS_TYPE_UINT16: {
      dbus_uint16_t uint16 = strtoul(value, NULL, 0);
      ret = dbus_message_iter_append_basic(iter, DBUS_TYPE_UINT16, &uint16);
    } break;
    case DBUS_TYPE_INT32: {
      dbus_int32_t int32 = strtol(value, NULL, 0);
      ret = dbus_message_iter_append_basic(iter, DBUS_TYPE_INT32, &int32);
    } break;
    case DBUS_TYPE_UINT32: {
      dbus_uint32_t uint32;
      // printf("append_arg UINT32: %s\n", value);
      uint32 = strtoul(value, NULL, 0);
      ret = dbus_message_iter_append_basic(iter, DBUS_TYPE_UINT32, &uint32);
    } break;
    case DBUS_TYPE_INT64: {
      dbus_int64_t int64 = strtoll(value, NULL, 0);
      ret = dbus_message_iter_append_basic(iter, DBUS_TYPE_INT64, &int64);
    } break;
    case DBUS_TYPE_UINT64: {
      dbus_uint64_t uint64 = strtoull(value, NULL, 0);
      ret = dbus_message_iter_append_basic(iter, DBUS_TYPE_UINT64, &uint64);
    } break;
    case DBUS_TYPE_BOOLEAN: {
      dbus_bool_t boolean;
      if ([argument isKindOfClass:[NSNumber class]]) {
        boolean = [argument boolValue] ? TRUE : FALSE;
      }
      ret = dbus_message_iter_append_basic(iter, DBUS_TYPE_BOOLEAN, &boolean);
    } break;
    case DBUS_TYPE_STRING: {
      // printf("append_arg STRING: %s\n", value);
      ret = dbus_message_iter_append_basic(iter, DBUS_TYPE_STRING, &value);
    } break;
    case DBUS_TYPE_OBJECT_PATH: {
      ret = dbus_message_iter_append_basic(iter, DBUS_TYPE_OBJECT_PATH, &value);
    } break;
    case DBUS_TYPE_ARRAY: {
      dbus_signature++;
      // NSLog(@"DBUS_TYPE_ARRAY: %@", argument);
      append_array(iter, argument, dbus_signature);
      ret = true;
    } break;
    case DBUS_STRUCT_BEGIN_CHAR: {
      dbus_signature++;
      // NSLog(@"DBUS_TYPE_STRUCT: %@", argument);
      append_struct(iter, argument, dbus_signature);
      ret = true;
    } break;
    default:
      fprintf(stderr, "OSEBusessage: Unsupported data type specified %c\n", dbus_signature[0]);
      exit(1);
  }
  handle_oom(ret);
  return ret;
}

// static void append_variant(DBusMessageIter *iter, int type, const char *value)
// {
//   // DBusMessageIter subiter;
//   // char sig[2] = "\0\0";
//   // char *subtype = strdup(value);
//   // char *c = NULL;

//   // handle_oom(subtype != NULL);

//   // c = strchr(subtype, ':');
//   // if (!c) {
//   //   fprintf(stderr, "BKMesage: missing variant subtype specifier\n");
//   //   exit(1);
//   // }
//   // *c = '\0';
//   // sig[0] = (char)type_from_name(subtype, TRUE);

//   // handle_oom(dbus_message_iter_open_container(iter, DBUS_TYPE_VARIANT, sig, &subiter));
//   // append_arg(&subiter, sig[0], c + 1);
//   // free(subtype);
//   // handle_oom(dbus_message_iter_close_container(iter, &subiter));
// }

// static void append_dict(DBusMessageIter *iter, int keytype, int valtype, const char *value)
// {
//   const char *val;
//   char *dupval = strdup(value);

//   handle_oom(dupval != NULL);

//   val = strtok(dupval, ",");
//   while (val != NULL) {
//     DBusMessageIter subiter;

//     handle_oom(dbus_message_iter_open_container(iter, DBUS_TYPE_DICT_ENTRY, NULL, &subiter));
//     append_arg(&subiter, keytype, val);
//     val = strtok(NULL, ",");
//     if (val == NULL) {
//       fprintf(stderr, "BKMessage: Malformed dictionary\n");
//       exit(1);
//     }
//     append_arg(&subiter, valtype, val);
//     handle_oom(dbus_message_iter_close_container(iter, &subiter));
//     val = strtok(NULL, ",");
//   }

//   free(dupval);
// }

@implementation OSEBusMessage

- (void)dealloc
{
  if (dbus_message) {
    dbus_message_unref(dbus_message);
  }
  [super dealloc];
}

- (instancetype)initWithService:(OSEBusService *)service
                      interface:(NSString *)interfacePath
                         method:(NSString *)methodName
{
  busService = service;
  return [self initWithService:service.serviceName
                        object:service.objectPath
                     interface:interfacePath
                        method:methodName];
}

- (instancetype)initWithService:(OSEBusService *)service
                      interface:(NSString *)interfacePath
                         method:(NSString *)methodName
                      arguments:(NSArray *)args
                      signature:(NSString *)signature
{
  busService = service;
  return [self initWithService:service.serviceName
                        object:service.objectPath
                     interface:interfacePath
                        method:methodName
                     arguments:args
                     signature:signature];
}

- (instancetype)initWithService:(NSString *)servicePath
                         object:(NSString *)objectPath
                      interface:(NSString *)interfacePath
                         method:(NSString *)methodName
                      arguments:(NSArray *)args
                      signature:(NSString *)signature
{
  [self initWithService:servicePath object:objectPath interface:interfacePath method:methodName];
  [self setMethodArguments:args withSignature:signature];

  return self;
}

// designated
- (instancetype)initWithService:(NSString *)servicePath
                         object:(NSString *)objectPath
                      interface:(NSString *)interfacePath
                         method:(NSString *)methodName
{
  [super init];

  dbus_message = dbus_message_new_method_call(NULL, [objectPath cString], [interfacePath cString],
                                              [methodName cString]);
  dbus_message_set_auto_start(dbus_message, TRUE);
  dbus_message_set_destination(dbus_message, [servicePath cString]);

  return self;
}

- (void)setMethodArguments:(NSArray *)args withSignature:(NSString *)signature
{
  if (args != nil) {
    const char *dbus_signature = [signature cString];

    // NSLog(@"Set method arguments: %@ with signature: %s", args, dbus_signature);

    dbus_message_iter_init_append(dbus_message, &_dbus_message_iterator);

    for (id argument in args) {
      append_arg(&_dbus_message_iterator, argument, dbus_signature);
      dbus_signature++;
    }
  }
}

- (id)send
{
  if (busService) {
    return [self sendWithConnection:busService.connection];
  }
  NSLog(@"OSBusMessage: called `send` without OSEBusService set. Return `nil`.");
  return nil;
}

- (id)sendWithConnection:(OSEBusConnection *)connection
{
  DBusMessage *reply;
  NSMutableArray *result = nil;

  dbus_error_init(&dbus_error);
  reply = dbus_connection_send_with_reply_and_block(connection.dbus_connection, dbus_message, -1,
                                                    &dbus_error);
  if (dbus_error_is_set(&dbus_error)) {
    NSLog(@"OSEBusMessage Error %s: %s\n", dbus_error.name, dbus_error.message);
    return nil;
  }
  if (reply) {
    result = [NSMutableArray new];

    dbus_message_iter_init(reply, &_dbus_message_iterator);
    decodeDBusMessage(&_dbus_message_iterator, result);
    dbus_message_unref(reply);
  }

  if (result && [result count] == 1) {
    return result[0];
  }

  return result;
}

- (id)decodeDBusMessage:(DBusMessage *)message
{
  NSMutableArray *result = [NSMutableArray new];

  dbus_message_iter_init(message, &_dbus_message_iterator);
  decodeDBusMessage(&_dbus_message_iterator, result);

  return result;
}

@end