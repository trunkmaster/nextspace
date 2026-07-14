#include "protocol.h"
#include "class.h"
#include "method.h"
#include "loader.h"

OBJC_PUBLIC struct objc_class _OBJC_CLASS_Object;

static struct objc_class _OBJC_METACLASS_Object = {
	.isa = NULL,
	.name = "Object",
	.info = objc_class_flag_meta,
};
OBJC_PUBLIC struct objc_class _OBJC_CLASS_Object = {
	.isa = &_OBJC_METACLASS_Object,
	.super_class = NULL,
	.name = "Object",
};

static struct objc_class _OBJC_METACLASS_Protocol = {
	.isa = &_OBJC_METACLASS_Object,
	.super_class = &_OBJC_METACLASS_Object,
	.name = "Protocol",
	.info = objc_class_flag_meta,
};
static struct objc_class _OBJC_METACLASS_ProtocolGCC = {
	.isa = &_OBJC_METACLASS_Object,
	.super_class = &_OBJC_METACLASS_Object,
	.name = "ProtocolGCC",
	.info = objc_class_flag_meta,
};
static struct objc_class _OBJC_METACLASS_ProtocolGSv1 = {
	.isa = &_OBJC_METACLASS_Object,
	.super_class = &_OBJC_METACLASS_Object,
	.name = "ProtocolGSv2",
	.info = objc_class_flag_meta,
};
static struct objc_class _OBJC_METACLASS___IncompleteProtocol = {
	.isa = &_OBJC_METACLASS_Object,
	.super_class = &_OBJC_METACLASS_Object,
	.name = "ProtocolGCC",
	.info = objc_class_flag_meta,
};

OBJC_PUBLIC struct objc_class _OBJC_CLASS_Protocol = {
	.isa = &_OBJC_METACLASS_Protocol,
	.super_class = &_OBJC_CLASS_Object,
	.name = "Protocol",
	.info = objc_class_flag_permanent_instances,
};

OBJC_PUBLIC struct objc_class _OBJC_CLASS_ProtocolGCC = {
	.isa = &_OBJC_METACLASS_ProtocolGCC,
	.super_class = &_OBJC_CLASS_Protocol,
	.name = "ProtocolGCC",
	.info = objc_class_flag_permanent_instances,
};

OBJC_PUBLIC struct objc_class _OBJC_CLASS___IncompleteProtocol = {
	.isa = &_OBJC_METACLASS_Protocol,
	.super_class = &_OBJC_CLASS_Protocol,
	.name = "__IncompleteProtocol",
	.info = objc_class_flag_permanent_instances,
};

OBJC_PUBLIC struct objc_class _OBJC_CLASS_ProtocolGSv1 = {
	.isa = &_OBJC_METACLASS_Protocol,
	.super_class = &_OBJC_CLASS_Protocol,
	.name = "ProtocolGSv1",
	.info = objc_class_flag_permanent_instances,
};

#ifdef OLDABI_COMPAT
static struct objc_class _OBJC_METACLASS___ObjC_Protocol_Holder_Ugly_Hack = {
	.isa = NULL,
	.name = "__ObjC_Protocol_Holder_Ugly_Hack",
	.info = objc_class_flag_meta,
};
OBJC_PUBLIC struct objc_class _OBJC_CLASS__ObjC_Protocol_Holder_Ugly_Hack = {
	.isa = &_OBJC_METACLASS___ObjC_Protocol_Holder_Ugly_Hack,
	.super_class = NULL,
	.name = "__ObjC_Protocol_Holder_Ugly_Hack",
};
#endif

PRIVATE void init_builtin_classes(void)
{
	// Load the classes that are compiled into the runtime.
	objc_load_class(&_OBJC_CLASS_Object);
	objc_load_class(&_OBJC_CLASS_Protocol);
	objc_load_class(&_OBJC_CLASS_ProtocolGCC);
	objc_load_class(&_OBJC_CLASS_ProtocolGSv1);
	objc_load_class(&_OBJC_CLASS___IncompleteProtocol);
	objc_resolve_class(&_OBJC_CLASS_Object);
	objc_resolve_class(&_OBJC_CLASS_Protocol);
	objc_resolve_class(&_OBJC_CLASS_ProtocolGCC);
	objc_resolve_class(&_OBJC_CLASS_ProtocolGSv1);
	objc_resolve_class(&_OBJC_CLASS___IncompleteProtocol);
	// Fix up the sizes of the various protocol classes that we will use.
	_OBJC_CLASS_Object.instance_size = sizeof(void*);
	_OBJC_CLASS_Protocol.instance_size = sizeof(struct objc_protocol);
	_OBJC_CLASS___IncompleteProtocol.instance_size = sizeof(struct objc_protocol);
#ifdef OLDABI_COMPAT
	objc_load_class(&_OBJC_CLASS__ObjC_Protocol_Holder_Ugly_Hack);
	objc_resolve_class(&_OBJC_CLASS__ObjC_Protocol_Holder_Ugly_Hack);
#endif
}
