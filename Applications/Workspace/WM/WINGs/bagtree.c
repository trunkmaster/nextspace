
#include <stdlib.h>
#include <string.h>

#include "WUtil.h"

typedef struct W_Node {
	struct W_Node *parent;
	struct W_Node *left;
	struct W_Node *right;
	int color;

	void *data;
	int index;
} W_Node;

typedef struct W_Bag {
	W_Node *root;

	W_Node *nil;		/* sentinel */

	int count;

	void (*destructor) (void *item);
} W_Bag;

#define IS_LEFT(node) (node == node->parent->left)
#define IS_RIGHT(node) (node == node->parent->right)

static void leftRotate(W_Bag * tree, W_Node * node)
{
	W_Node *node2;

	node2 = node->right;
	node->right = node2->left;

	node2->left->parent = node;

	node2->parent = node->parent;

	if (node->parent == tree->nil) {
		tree->root = node2;
	} else {
		if (IS_LEFT(node)) {
			node->parent->left = node2;
		} else {
			node->parent->right = node2;
		}
	}
	node2->left = node;
	node->parent = node2;
}

static void rightRotate(W_Bag * tree, W_Node * node)
{
	W_Node *node2;

	node2 = node->left;
	node->left = node2->right;

	node2->right->parent = node;

	node2->parent = node->parent;

	if (node->parent == tree->nil) {
		tree->root = node2;
	} else {
		if (IS_LEFT(node)) {
			node->parent->left = node2;
		} else {
			node->parent->right = node2;
		}
	}
	node2->right = node;
	node->parent = node2;
}

static void treeInsert(W_Bag * tree, W_Node * node)
{
	W_Node *y = tree->nil;
	W_Node *x = tree->root;

	while (x != tree->nil) {
		y = x;
		if (node->index <= x->index)
			x = x->left;
		else
			x = x->right;
	}
	node->parent = y;
	if (y == tree->nil)
		tree->root = node;
	else if (node->index <= y->index)
		y->left = node;
	else
		y->right = node;
}

static void rbTreeInsert(W_Bag * tree, W_Node * node)
{
	W_Node *y;

	treeInsert(tree, node);

	node->color = 'R';

	while (node != tree->root && node->parent->color == 'R') {
		if (IS_LEFT(node->parent)) {
			y = node->parent->parent->right;

			if (y->color == 'R') {

				node->parent->color = 'B';
				y->color = 'B';
				node->parent->parent->color = 'R';
				node = node->parent->parent;

			} else {
				if (IS_RIGHT(node)) {
					node = node->parent;
					leftRotate(tree, node);
				}
				node->parent->color = 'B';
				node->parent->parent->color = 'R';
				rightRotate(tree, node->parent->parent);
			}
		} else {
			y = node->parent->parent->left;

			if (y->color == 'R') {

				node->parent->color = 'B';
				y->color = 'B';
				node->parent->parent->color = 'R';
				node = node->parent->parent;

			} else {
				if (IS_LEFT(node)) {
					node = node->parent;
					rightRotate(tree, node);
				}
				node->parent->color = 'B';
				node->parent->parent->color = 'R';
				leftRotate(tree, node->parent->parent);
			}
		}
	}
	tree->root->color = 'B';
}

static void rbDeleteFixup(W_Bag * tree, W_Node * node)
{
	W_Node *w;

	while (node != tree->root && node->color == 'B') {
		if (IS_LEFT(node)) {
			w = node->parent->right;
			if (w->color == 'R') {
				w->color = 'B';
				node->parent->color = 'R';
				leftRotate(tree, node->parent);
				w = node->parent->right;
			}
			if (w->left->color == 'B' && w->right->color == 'B') {
				w->color = 'R';
				node = node->parent;
			} else {
				if (w->right->color == 'B') {
					w->left->color = 'B';
					w->color = 'R';
					rightRotate(tree, w);
					w = node->parent->right;
				}
				w->color = node->parent->color;
				node->parent->color = 'B';
				w->right->color = 'B';
				leftRotate(tree, node->parent);
				node = tree->root;
			}
		} else {
			w = node->parent->left;
			if (w->color == 'R') {
				w->color = 'B';
				node->parent->color = 'R';
				rightRotate(tree, node->parent);
				w = node->parent->left;
			}
			if (w->left->color == 'B' && w->right->color == 'B') {
				w->color = 'R';
				node = node->parent;
			} else {
				if (w->left->color == 'B') {
					w->right->color = 'B';
					w->color = 'R';
					leftRotate(tree, w);
					w = node->parent->left;
				}
				w->color = node->parent->color;
				node->parent->color = 'B';
				w->left->color = 'B';
				rightRotate(tree, node->parent);
				node = tree->root;
			}
		}
	}
	node->color = 'B';

}

static W_Node *treeMinimum(W_Node * node, W_Node * nil)
{
	while (node->left != nil)
		node = node->left;
	return node;
}

static W_Node *treeMaximum(W_Node * node, W_Node * nil)
{
	while (node->right != nil)
		node = node->right;
	return node;
}

static W_Node *treeSuccessor(W_Node * node, W_Node * nil)
{
	W_Node *y;

	if (node->right != nil) {
		return treeMinimum(node->right, nil);
	}
	y = node->parent;
	while (y != nil && node == y->right) {
		node = y;
		y = y->parent;
	}
	return y;
}

static W_Node *treePredecessor(W_Node * node, W_Node * nil)
{
	W_Node *y;

	if (node->left != nil) {
		return treeMaximum(node->left, nil);
	}
	y = node->parent;
	while (y != nil && node == y->left) {
		node = y;
		y = y->parent;
	}
	return y;
}

static W_Node *rbTreeDelete(W_Bag * tree, W_Node * node)
{
	W_Node *nil = tree->nil;
	W_Node *x, *y;

	if (node->left == nil || node->right == nil) {
		y = node;
	} else {
		y = treeSuccessor(node, nil);
	}

	if (y->left != nil) {
		x = y->left;
	} else {
		x = y->right;
	}

	x->parent = y->parent;

	if (y->parent == nil) {
		tree->root = x;
	} else {
		if (IS_LEFT(y)) {
			y->parent->left = x;
		} else {
			y->parent->right = x;
		}
	}
	if (y != node) {
		node->index = y->index;
		node->data = y->data;
	}
	if (y->color == 'B') {
		rbDeleteFixup(tree, x);
	}

	return y;
}

static W_Node *treeSearch(W_Node * root, W_Node * nil, int index)
{
	if (root == nil || root->index == index) {
		return root;
	}

	if (index < root->index) {
		return treeSearch(root->left, nil, index);
	} else {
		return treeSearch(root->right, nil, index);
	}
}

static W_Node *treeFind(W_Node * root, W_Node * nil, void *data)
{
	W_Node *tmp;

	if (root == nil || root->data == data)
		return root;

	tmp = treeFind(root->left, nil, data);
	if (tmp != nil)
		return tmp;

	tmp = treeFind(root->right, nil, data);

	return tmp;
}

#if 0
static char buf[512];

static void printNodes(W_Node * node, W_Node * nil, int depth)
{
	if (node == nil) {
		return;
	}

	printNodes(node->left, nil, depth + 1);

	memset(buf, ' ', depth * 2);
	buf[depth * 2] = 0;
	if (IS_LEFT(node))
		printf("%s/(%2i\n", buf, node->index);
	else
		printf("%s\\(%2i\n", buf, node->index);

	printNodes(node->right, nil, depth + 1);
}

void PrintTree(WMBag * bag)
{
	W_TreeBag *tree = (W_TreeBag *) bag->data;

	printNodes(tree->root, tree->nil, 0);
}
#endif

WMBag *WMCreateTreeBag(void)
{
	return WMCreateTreeBagWithDestructor(NULL);
}

WMBag *WMCreateTreeBagWithDestructor(WMFreeDataProc * destructor)
{
	WMBag *bag;

	bag = wmalloc(sizeof(WMBag));
	bag->nil = wmalloc(sizeof(W_Node));
	bag->nil->left = bag->nil->right = bag->nil->parent = bag->nil;
	bag->nil->index = WBNotFound;
	bag->root = bag->nil;
	bag->destructor = destructor;

	return bag;
}

int WMGetBagItemCount(WMBag * self)
{
	return self->count;
}

void WMAppendBag(WMBag * self, WMBag * bag)
{
	WMBagIterator ptr;
	void *data;

	for (data = WMBagFirst(bag, &ptr); data != NULL; data = WMBagNext(bag, &ptr)) {
		WMPutInBag(self, data);
	}
}

void WMPutInBag(WMBag * self, void *item)
{
	W_Node *ptr;

	ptr = wmalloc(sizeof(W_Node));

	ptr->data = item;
	ptr->index = self->count;
	ptr->left = self->nil;
	ptr->right = self->nil;
	ptr->parent = self->nil;

	rbTreeInsert(self, ptr);

	self->count++;
}

void WMInsertInBag(WMBag * self, int index, void *item)
{
	W_Node *ptr;

	ptr = wmalloc(sizeof(W_Node));

	ptr->data = item;
	ptr->index = index;
	ptr->left = self->nil;
	ptr->right = self->nil;
	ptr->parent = self->nil;

	rbTreeInsert(self, ptr);

	while ((ptr = treeSuccessor(ptr, self->nil)) != self->nil) {
		ptr->index++;
	}

	self->count++;
}

static int treeDeleteNode(WMBag * self, W_Node *ptr)
{
	if (ptr != self->nil) {
		W_Node *tmp;

		self->count--;

		tmp = treeSuccessor(ptr, self->nil);
		while (tmp != self->nil) {
			tmp->index--;
			tmp = treeSuccessor(tmp, self->nil);
		}

		ptr = rbTreeDelete(self, ptr);
		if (self->destructor)
			self->destructor(ptr->data);
		wfree(ptr);
		return 1;
	}
	return 0;
}

int WMRemoveFromBag(WMBag * self, void *item)
{
	W_Node *ptr = treeFind(self->root, self->nil, item);
	return treeDeleteNode(self, ptr);
}

int WMEraseFromBag(WMBag * self, int index)
{
	W_Node *ptr = treeSearch(self->root, self->nil, index);

	if (ptr != self->nil) {

		self->count--;

		ptr = rbTreeDelete(self, ptr);
		if (self->destructor)
			self->destructor(ptr->data);
		wfree(ptr);

		wassertrv(self->count == 0 || self->root->index >= 0, 1);

		return 1;
	} else {
		return 0;
	}
}

int WMDeleteFromBag(WMBag * self, int index)
{
	W_Node *ptr = treeSearch(self->root, self->nil, index);
	return treeDeleteNode(self, ptr);
}

void *WMGetFromBag(WMBag * self, int index)
{
	W_Node *node;

	node = treeSearch(self->root, self->nil, index);
	if (node != self->nil)
		return node->data;
	else
		return NULL;
}

int WMGetFirstInBag(WMBag * self, void *item)
{
	W_Node *node;

	node = treeFind(self->root, self->nil, item);
	if (node != self->nil)
		return node->index;
	else
		return WBNotFound;
}

static int treeCount(W_Node * root, W_Node * nil, void *item)
{
	int count = 0;

	if (root == nil)
		return 0;

	if (root->data == item)
		count++;

	if (root->left != nil)
		count += treeCount(root->left, nil, item);

	if (root->right != nil)
		count += treeCount(root->right, nil, item);

	return count;
}

int WMCountInBag(WMBag * self, void *item)
{
	return treeCount(self->root, self->nil, item);
}

void *WMReplaceInBag(WMBag * self, int index, void *item)
{
	W_Node *ptr = treeSearch(self->root, self->nil, index);
	void *old = NULL;

	if (item == NULL) {
		self->count--;
		ptr = rbTreeDelete(self, ptr);
		if (self->destructor)
			self->destructor(ptr->data);
		wfree(ptr);
	} else if (ptr != self->nil) {
		old = ptr->data;
		ptr->data = item;
	} else {
		W_Node *ptr;

		ptr = wmalloc(sizeof(W_Node));

		ptr->data = item;
		ptr->index = index;
		ptr->left = self->nil;
		ptr->right = self->nil;
		ptr->parent = self->nil;

		rbTreeInsert(self, ptr);

		self->count++;
	}

	return old;
}

void WMSortBag(WMBag * self, WMCompareDataProc * comparer)
{
	void **items;
	W_Node *tmp;
	int i;

	if (self->count == 0)
		return;

	items = wmalloc(sizeof(void *) * self->count);
	i = 0;

	tmp = treeMinimum(self->root, self->nil);
	while (tmp != self->nil) {
		items[i++] = tmp->data;
		tmp = treeSuccessor(tmp, self->nil);
	}

	qsort(&items[0], self->count, sizeof(void *), comparer);

	i = 0;
	tmp = treeMinimum(self->root, self->nil);
	while (tmp != self->nil) {
		tmp->index = i;
		tmp->data = items[i++];
		tmp = treeSuccessor(tmp, self->nil);
	}

	wfree(items);
}

static void deleteTree(WMBag * self, W_Node * node)
{
	if (node == self->nil)
		return;

	deleteTree(self, node->left);

	if (self->destructor)
		self->destructor(node->data);

	deleteTree(self, node->right);

	wfree(node);
}

void WMEmptyBag(WMBag * self)
{
	deleteTree(self, self->root);
	self->root = self->nil;
	self->count = 0;
}

void WMFreeBag(WMBag * self)
{
	WMEmptyBag(self);
	wfree(self->nil);
	wfree(self);
}

static void mapTree(W_Bag * tree, W_Node * node, void (*function) (void *, void *), void *data)
{
	if (node == tree->nil)
		return;

	mapTree(tree, node->left, function, data);

	(*function) (node->data, data);

	mapTree(tree, node->right, function, data);
}

void WMMapBag(WMBag * self, void (*function) (void *, void *), void *data)
{
	mapTree(self, self->root, function, data);
}

static int findInTree(W_Bag * tree, W_Node * node, WMMatchDataProc * function, void *cdata)
{
	int index;

	if (node == tree->nil)
		return WBNotFound;

	index = findInTree(tree, node->left, function, cdata);
	if (index != WBNotFound)
		return index;

	if ((*function) (node->data, cdata)) {
		return node->index;
	}

	return findInTree(tree, node->right, function, cdata);
}

int WMFindInBag(WMBag * self, WMMatchDataProc * match, void *cdata)
{
	return findInTree(self, self->root, match, cdata);
}

void *WMBagFirst(WMBag * self, WMBagIterator * ptr)
{
	W_Node *node;

	node = treeMinimum(self->root, self->nil);

	if (node == self->nil) {
		*ptr = NULL;
		return NULL;
	} else {
		*ptr = node;
		return node->data;
	}
}

void *WMBagLast(WMBag * self, WMBagIterator * ptr)
{

	W_Node *node;

	node = treeMaximum(self->root, self->nil);

	if (node == self->nil) {
		*ptr = NULL;
		return NULL;
	} else {
		*ptr = node;
		return node->data;
	}
}

void *WMBagNext(WMBag * self, WMBagIterator * ptr)
{
	W_Node *node;

	if (*ptr == NULL)
		return NULL;

	node = treeSuccessor(*ptr, self->nil);

	if (node == self->nil) {
		*ptr = NULL;
		return NULL;
	} else {
		*ptr = node;
		return node->data;
	}
}

void *WMBagPrevious(WMBag * self, WMBagIterator * ptr)
{
	W_Node *node;

	if (*ptr == NULL)
		return NULL;

	node = treePredecessor(*ptr, self->nil);

	if (node == self->nil) {
		*ptr = NULL;
		return NULL;
	} else {
		*ptr = node;
		return node->data;
	}
}

void *WMBagIteratorAtIndex(WMBag * self, int index, WMBagIterator * ptr)
{
	W_Node *node;

	node = treeSearch(self->root, self->nil, index);

	if (node == self->nil) {
		*ptr = NULL;
		return NULL;
	} else {
		*ptr = node;
		return node->data;
	}
}

int WMBagIndexForIterator(WMBag * bag, WMBagIterator ptr)
{
	/* Parameter not used, but tell the compiler that it is ok */
	(void) bag;

	return ((W_Node *) ptr)->index;
}
