#import "BKTypes.h"
#import "BKMessage.h"

// Is not recursive
static id getBasicType(DBusMessageIter *iter)
{
  int type = dbus_message_iter_get_arg_type(iter);

  if (type == DBUS_TYPE_INVALID) {
    return nil;
  }

  switch (type) {
    case DBUS_TYPE_STRING: {
      char *val;
      dbus_message_iter_get_basic(iter, &val);
      return [NSString stringWithCString:val];
      break;
    }

    case DBUS_TYPE_BYTE: {
      unsigned char val;
      dbus_message_iter_get_basic(iter, &val);
      return [NSString stringWithFormat:@"%c", val];
      break;
    }

    case DBUS_TYPE_SIGNATURE: {
      char *val;
      dbus_message_iter_get_basic(iter, &val);
      return [NSString stringWithCString:val];
      break;
    }

    case DBUS_TYPE_OBJECT_PATH: {
      char *val;
      dbus_message_iter_get_basic(iter, &val);
      return [NSString stringWithCString:val];
      break;
    }

    case DBUS_TYPE_INT16: {
      dbus_int16_t val;
      dbus_message_iter_get_basic(iter, &val);
      return [NSNumber numberWithInt:val];
      break;
    }

    case DBUS_TYPE_UINT16: {
      dbus_uint16_t val;
      dbus_message_iter_get_basic(iter, &val);
      return [NSNumber numberWithUnsignedInt:val];
      break;
    }

    case DBUS_TYPE_INT32: {
      dbus_int32_t val;
      dbus_message_iter_get_basic(iter, &val);
      return [NSNumber numberWithInt:val];
      break;
    }

    case DBUS_TYPE_UINT32: {
      dbus_uint32_t val;
      dbus_message_iter_get_basic(iter, &val);
      return [NSNumber numberWithUnsignedInt:val];
      break;
    }

    case DBUS_TYPE_INT64: {
      dbus_int64_t val;
      dbus_message_iter_get_basic(iter, &val);
      return [NSNumber numberWithUnsignedInt:val];
      break;
    }

    case DBUS_TYPE_UINT64: {
      dbus_uint64_t val;
      dbus_message_iter_get_basic(iter, &val);
      return [NSNumber numberWithUnsignedInt:val];
      break;
    }

    case DBUS_TYPE_DOUBLE: {
      double val;
      dbus_message_iter_get_basic(iter, &val);
      return [NSNumber numberWithDouble:val];
      break;
    }

    case DBUS_TYPE_BOOLEAN: {
      dbus_bool_t val;
      dbus_message_iter_get_basic(iter, &val);
      return [NSNumber numberWithUnsignedInt:val];
      break;
    }
  }
  return nil;
}

// Is recursive. `result` have to be set at the first call to this function.
static id marshallIterator(DBusMessageIter *iter, id result)
{
  do {
    int type = dbus_message_iter_get_arg_type(iter);
    id basicResult;

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
      DBusMessageIter subiter;
      dbus_message_iter_recurse(iter, &subiter);
      result = marshallIterator(&subiter, nil);
      break;
    } else if (type == DBUS_TYPE_ARRAY || type == DBUS_TYPE_STRUCT) {
      DBusMessageIter subiter;
      NSMutableArray *subiter_result = [NSMutableArray array];
      id object;

      // printf("array\n");

      dbus_message_iter_recurse(iter, &subiter);
      while (dbus_message_iter_get_arg_type(&subiter) != DBUS_TYPE_INVALID) {
        object = marshallIterator(&subiter, nil);
        if (object) {
          [subiter_result addObject:object];
        }
        dbus_message_iter_next(&subiter);
      }

      if (result != nil) {
        [result addObject:subiter_result];
      } else {
        result = subiter_result;
        break;
      }
    } else if (type == DBUS_TYPE_DICT_ENTRY) {
      DBusMessageIter subiter;
      id key, object;

      // printf("dict_entry\n");

      dbus_message_iter_recurse(iter, &subiter);
      key = getBasicType(&subiter);
      dbus_message_iter_next(&subiter);
      object = marshallIterator(&subiter, nil);
      result = @{key : object};

      break;
    } else {
      NSLog(@"BusKit error: unknown D-Bus data type '%c'", type);
    }
  } while (dbus_message_iter_next(iter));

  return result;
}

static void unmarshallArgument(id argument, DBusMessageIter *iter)
{
  
}

@implementation BKMessage

- (void)dealloc
{
  dbus_message_unref(dbus_message);
  [super dealloc];
}

- (instancetype)initWithObject:(const char *)object_path
                     interface:(const char *)interface_path
                        method:(const char *)method_name
                       service:(const char *)service_path
{
  [super init];

  dbus_message = dbus_message_new_method_call(NULL, object_path, interface_path, method_name);
  dbus_message_set_auto_start(dbus_message, TRUE);
  dbus_message_set_destination(dbus_message, service_path);

  return self;
}

- (void)_appendStructureArgument:(BKStructure *)argument
{
  
}

- (void)setMethodArguments:(NSArray *)args withSignature:(NSString *)signature
{
  dbus_message_iter_init_append(dbus_message, &dbus_message_iterator);

  if (args != nil) {
    id argument;
    // Iterate trough NSArray and fill message with arguments
    NSLog(@"[BKMessage setMethodArguments:] %@ signature: %@", args, signature);
    for (int i = 0; i < [args count]; i++) {
      argument = args[i];

      if ([signature characterAtIndex:i] == DBUS_TYPE_STRING) {
        if ([argument isKindOfClass:[NSString class]] != NO) {
          NSLog(@"argument type: STRING");
          const char *value = [argument cString];
          dbus_message_iter_append_basic(&dbus_message_iterator, DBUS_TYPE_STRING, &value);
        } else {
          // argument type mismatch
        }
      } else if ([signature characterAtIndex:i] == DBUS_TYPE_DOUBLE) {
        if ([argument isKindOfClass:[NSNumber class]] != NO) {
          NSLog(@"argument type: DOUBLE");
          double value = [argument doubleValue];
          dbus_message_iter_append_basic(&dbus_message_iterator, DBUS_TYPE_DOUBLE, &value);
        }
      } else if ([signature characterAtIndex:i] == DBUS_TYPE_UINT32) {
        if ([argument isKindOfClass:[NSNumber class]] != NO) {
          NSLog(@"argument type: UINT32");
          double value = [argument doubleValue];
          dbus_message_iter_append_basic(&dbus_message_iterator, DBUS_TYPE_DOUBLE, &value);
        }
      } else if ([signature characterAtIndex:i] == '(') {
        if ([argument isKindOfClass:[NSArray class]] != NO) {
          NSLog(@"argument type: STRUCT");
          double value = [argument doubleValue];
          dbus_message_iter_append_basic(&dbus_message_iterator, DBUS_TYPE_DOUBLE, &value);
        }
      }

    }
  }
}

- (id)sendWithConnection:(BKConnection *)connection
{
  DBusMessage *reply;
  NSMutableArray *result = nil;

  dbus_error_init(&dbus_error);
  reply = dbus_connection_send_with_reply_and_block([connection dbusConnection], dbus_message, -1,
                                                    &dbus_error);
  if (dbus_error_is_set(&dbus_error)) {
    NSLog(@"Error %s: %s\n", dbus_error.name, dbus_error.message);
    return nil;
  }
  if (reply) {
    result = [NSMutableArray new];

    dbus_message_iter_init(reply, &dbus_message_iterator);
    marshallIterator(&dbus_message_iterator, result);
    dbus_message_unref(reply);
  }

  return result;
}

@end