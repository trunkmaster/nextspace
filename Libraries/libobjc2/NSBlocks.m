#include "objc/runtime.h"
#include "class.h"
#include "loader.h"
#include "lock.h"
#include "objc/blocks_runtime.h"
#include "dtable.h"
#include <assert.h>

#ifdef EMBEDDED_BLOCKS_RUNTIME
#define BLOCK_STORAGE OBJC_PUBLIC
#else
#define BLOCK_STORAGE extern
#endif

BLOCK_STORAGE struct objc_class _NSConcreteGlobalBlock;
BLOCK_STORAGE struct objc_class _NSConcreteStackBlock;
BLOCK_STORAGE struct objc_class _NSConcreteMallocBlock;
BLOCK_STORAGE struct objc_class _NSConcreteAutoBlock;
BLOCK_STORAGE struct objc_class _NSConcreteFinalizingBlock;

static struct objc_class _NSConcreteGlobalBlockMeta;
static struct objc_class _NSConcreteStackBlockMeta;
static struct objc_class _NSConcreteMallocBlockMeta;
static struct objc_class _NSConcreteAutoBlockMeta;
static struct objc_class _NSConcreteFinalizingBlockMeta;

static struct objc_class _NSBlock;
static struct objc_class _NSBlockMeta;

static void createNSBlockSubclass(Class superclass, Class newClass, 
		Class metaClass, char *name)
{
	// Initialize the metaclass
	//metaClass->class_pointer = superclass->class_pointer;
	//metaClass->super_class = superclass->class_pointer;
	metaClass->info = objc_class_flag_meta;
	metaClass->dtable = uninstalled_dtable;

	// Set up the new class
	newClass->isa = metaClass;
	newClass->super_class = superclass;
	newClass->name = name;
	newClass->dtable = uninstalled_dtable;
	newClass->info = objc_class_flag_is_block;

	LOCK_RUNTIME_FOR_SCOPE();
	objc_load_class(newClass);

}

#define NEW_CLASS(super, sub) \
	createNSBlockSubclass(super, &sub, &sub ## Meta, #sub)

OBJC_PUBLIC
BOOL objc_create_block_classes_as_subclasses_of(Class super)
{
	if (_NSBlock.super_class != NULL) { return NO; }

	NEW_CLASS(super, _NSBlock);
	NEW_CLASS(&_NSBlock, _NSConcreteStackBlock);
	NEW_CLASS(&_NSBlock, _NSConcreteGlobalBlock);
	NEW_CLASS(&_NSBlock, _NSConcreteMallocBlock);
	NEW_CLASS(&_NSBlock, _NSConcreteAutoBlock);
	NEW_CLASS(&_NSBlock, _NSConcreteFinalizingBlock);
	// Global blocks never need refcount manipulation.
	objc_set_class_flag(&_NSConcreteGlobalBlock,
	                    objc_class_flag_permanent_instances);
	return YES;
}

PRIVATE void init_early_blocks(void)
{
	if (_NSBlock.super_class != NULL) { return; }
	_NSConcreteStackBlock.info = objc_class_flag_is_block;
	_NSConcreteGlobalBlock.info = objc_class_flag_is_block | objc_class_flag_permanent_instances;
	_NSConcreteMallocBlock.info = objc_class_flag_is_block;
	_NSConcreteAutoBlock.info = objc_class_flag_is_block;
	_NSConcreteFinalizingBlock.info = objc_class_flag_is_block;
}