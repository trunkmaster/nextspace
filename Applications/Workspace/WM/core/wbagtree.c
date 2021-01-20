/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 2001 Dan Pascu
 *  Copyright (c) 2014 Window Maker Team
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

#include <stdlib.h>
#include <string.h>
#include <limits.h>

#include "WMcore.h"
#include "util.h"
#include "wbagtree.h"

int WBNotFound = INT_MIN;
    
#define IS_LEFT(node) (node == node->parent->left)
#define IS_RIGHT(node) (node == node->parent->right)

static void leftRotate(WMBag *tree, WMNode *node)
{
  WMNode *node2;

  node2 = node->right;
  node->right = node2->left;

  node2->left->parent = node;

  node2->parent = node->parent;

  if (node->parent == tree->sentinel) {
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

static void rightRotate(WMBag *tree, WMNode *node)
{
  WMNode *node2;

  node2 = node->left;
  node->left = node2->right;

  node2->right->parent = node;

  node2->parent = node->parent;

  if (node->parent == tree->sentinel) {
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

static void treeInsert(WMBag *tree, WMNode *node)
{
  WMNode *y = tree->sentinel;
  WMNode *x = tree->root;

  while (x != tree->sentinel) {
    y = x;
    if (node->index <= x->index)
      x = x->left;
    else
      x = x->right;
  }
  node->parent = y;
  if (y == tree->sentinel)
    tree->root = node;
  else if (node->index <= y->index)
    y->left = node;
  else
    y->right = node;
}

static void rbTreeInsert(WMBag *tree, WMNode *node)
{
  WMNode *y;

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

static void rbDeleteFixup(WMBag *tree, WMNode *node)
{
  WMNode *w;

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

static WMNode *treeMinimum(WMNode *node, WMNode *nil)
{
  while (node->left != nil)
    node = node->left;
  return node;
}

static WMNode *treeMaximum(WMNode *node, WMNode *nil)
{
  while (node->right != nil)
    node = node->right;
  return node;
}

static WMNode *treeSuccessor(WMNode *node, WMNode *nil)
{
  WMNode *y;

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

static WMNode *treePredecessor(WMNode *node, WMNode *nil)
{
  WMNode *y;

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

static WMNode *rbTreeDelete(WMBag *tree, WMNode *node)
{
  WMNode *nil = tree->sentinel;
  WMNode *x, *y;

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

static WMNode *treeSearch(WMNode *root, WMNode *nil, int index)
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

static WMNode *treeFind(WMNode *root, WMNode *nil, void *data)
{
  WMNode *tmp;

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

static void printNodes(WMNode *node, WMNode *nil, int depth)
{
  if (node == nil) {
    return;
  }

  printNodes(node->left, nil, depth + 1);

  memset(buf, ' ', depth *2);
  buf[depth *2] = 0;
  if (IS_LEFT(node))
    printf("%s/(%2i\n", buf, node->index);
  else
    printf("%s\\(%2i\n", buf, node->index);

  printNodes(node->right, nil, depth + 1);
}

void PrintTree(WMBag *bag)
{
  WMTreeBag *tree = (WMTreeBag *) bag->data;

  printNodes(tree->root, tree->sentinel, 0);
}
#endif

WMBag *WMCreateTreeBag(void)
{
  return WMCreateTreeBagWithDestructor(NULL);
}

WMBag *WMCreateTreeBagWithDestructor(WMFreeDataProc *destructor)
{
  WMBag *bag;

  bag = wmalloc(sizeof(WMBag));
  bag->sentinel = wmalloc(sizeof(WMNode));
  bag->sentinel->left = bag->sentinel->right = bag->sentinel->parent = bag->sentinel;
  bag->sentinel->index = WBNotFound;
  bag->root = bag->sentinel;
  bag->destructor = destructor;

  return bag;
}

int WMGetBagItemCount(WMBag *self)
{
  return self->count;
}

void WMAppendBag(WMBag *self, WMBag *bag)
{
  WMBagIterator ptr;
  void *data;

  for (data = WMBagFirst(bag, &ptr); data != NULL; data = WMBagNext(bag, &ptr)) {
    WMPutInBag(self, data);
  }
}

void WMPutInBag(WMBag *self, void *item)
{
  WMNode *ptr;

  ptr = wmalloc(sizeof(WMNode));

  ptr->data = item;
  ptr->index = self->count;
  ptr->left = self->sentinel;
  ptr->right = self->sentinel;
  ptr->parent = self->sentinel;

  rbTreeInsert(self, ptr);

  self->count++;
}

void WMInsertInBag(WMBag *self, int index, void *item)
{
  WMNode *ptr;

  ptr = wmalloc(sizeof(WMNode));

  ptr->data = item;
  ptr->index = index;
  ptr->left = self->sentinel;
  ptr->right = self->sentinel;
  ptr->parent = self->sentinel;

  rbTreeInsert(self, ptr);

  while ((ptr = treeSuccessor(ptr, self->sentinel)) != self->sentinel) {
    ptr->index++;
  }

  self->count++;
}

static int treeDeleteNode(WMBag *self, WMNode *ptr)
{
  if (ptr != self->sentinel) {
    WMNode *tmp;

    self->count--;

    tmp = treeSuccessor(ptr, self->sentinel);
    while (tmp != self->sentinel) {
      tmp->index--;
      tmp = treeSuccessor(tmp, self->sentinel);
    }

    ptr = rbTreeDelete(self, ptr);
    if (self->destructor)
      self->destructor(ptr->data);
    wfree(ptr);
    return 1;
  }
  return 0;
}

int WMRemoveFromBag(WMBag *self, void *item)
{
  WMNode *ptr = treeFind(self->root, self->sentinel, item);
  return treeDeleteNode(self, ptr);
}

int WMEraseFromBag(WMBag *self, int index)
{
  WMNode *ptr = treeSearch(self->root, self->sentinel, index);

  if (ptr != self->sentinel) {

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

int WMDeleteFromBag(WMBag *self, int index)
{
  WMNode *ptr = treeSearch(self->root, self->sentinel, index);
  return treeDeleteNode(self, ptr);
}

void *WMGetFromBag(WMBag *self, int index)
{
  WMNode *node;

  node = treeSearch(self->root, self->sentinel, index);
  if (node != self->sentinel)
    return node->data;
  else
    return NULL;
}

int WMGetFirstInBag(WMBag *self, void *item)
{
  WMNode *node;

  node = treeFind(self->root, self->sentinel, item);
  if (node != self->sentinel)
    return node->index;
  else
    return WBNotFound;
}

static int treeCount(WMNode *root, WMNode *nil, void *item)
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

int WMCountInBag(WMBag *self, void *item)
{
  return treeCount(self->root, self->sentinel, item);
}

void *WMReplaceInBag(WMBag *self, int index, void *item)
{
  WMNode *ptr = treeSearch(self->root, self->sentinel, index);
  void *old = NULL;

  if (item == NULL) {
    self->count--;
    ptr = rbTreeDelete(self, ptr);
    if (self->destructor)
      self->destructor(ptr->data);
    wfree(ptr);
  } else if (ptr != self->sentinel) {
    old = ptr->data;
    ptr->data = item;
  } else {
    WMNode *ptr;

    ptr = wmalloc(sizeof(WMNode));

    ptr->data = item;
    ptr->index = index;
    ptr->left = self->sentinel;
    ptr->right = self->sentinel;
    ptr->parent = self->sentinel;

    rbTreeInsert(self, ptr);

    self->count++;
  }

  return old;
}

void WMSortBag(WMBag *self, WMCompareDataProc *comparer)
{
  void **items;
  WMNode *tmp;
  int i;

  if (self->count == 0)
    return;

  items = wmalloc(sizeof(void *) *self->count);
  i = 0;

  tmp = treeMinimum(self->root, self->sentinel);
  while (tmp != self->sentinel) {
    items[i++] = tmp->data;
    tmp = treeSuccessor(tmp, self->sentinel);
  }

  qsort(&items[0], self->count, sizeof(void *), comparer);

  i = 0;
  tmp = treeMinimum(self->root, self->sentinel);
  while (tmp != self->sentinel) {
    tmp->index = i;
    tmp->data = items[i++];
    tmp = treeSuccessor(tmp, self->sentinel);
  }

  wfree(items);
}

static void deleteTree(WMBag *self, WMNode *node)
{
  if (node == self->sentinel)
    return;

  deleteTree(self, node->left);

  if (self->destructor)
    self->destructor(node->data);

  deleteTree(self, node->right);

  wfree(node);
}

void WMEmptyBag(WMBag *self)
{
  deleteTree(self, self->root);
  self->root = self->sentinel;
  self->count = 0;
}

void WMFreeBag(WMBag *self)
{
  WMEmptyBag(self);
  wfree(self->sentinel);
  wfree(self);
}

static void mapTree(WMBag *tree, WMNode *node, void (*function) (void *, void *), void *data)
{
  if (node == tree->sentinel)
    return;

  mapTree(tree, node->left, function, data);

  (*function) (node->data, data);

  mapTree(tree, node->right, function, data);
}

void WMMapBag(WMBag *self, void (*function) (void *, void *), void *data)
{
  mapTree(self, self->root, function, data);
}

static int findInTree(WMBag *tree, WMNode *node, WMMatchDataProc *function, void *cdata)
{
  int index;

  if (node == tree->sentinel)
    return WBNotFound;

  index = findInTree(tree, node->left, function, cdata);
  if (index != WBNotFound)
    return index;

  if ((*function) (node->data, cdata)) {
    return node->index;
  }

  return findInTree(tree, node->right, function, cdata);
}

int WMFindInBag(WMBag *self, WMMatchDataProc *match, void *cdata)
{
  return findInTree(self, self->root, match, cdata);
}

void *WMBagFirst(WMBag *self, WMBagIterator *ptr)
{
  WMNode *node;

  node = treeMinimum(self->root, self->sentinel);

  if (node == self->sentinel) {
    *ptr = NULL;
    return NULL;
  } else {
    *ptr = node;
    return node->data;
  }
}

void *WMBagLast(WMBag *self, WMBagIterator *ptr)
{

  WMNode *node;

  node = treeMaximum(self->root, self->sentinel);

  if (node == self->sentinel) {
    *ptr = NULL;
    return NULL;
  } else {
    *ptr = node;
    return node->data;
  }
}

void *WMBagNext(WMBag *self, WMBagIterator *ptr)
{
  WMNode *node;

  if (*ptr == NULL)
    return NULL;

  node = treeSuccessor(*ptr, self->sentinel);

  if (node == self->sentinel) {
    *ptr = NULL;
    return NULL;
  } else {
    *ptr = node;
    return node->data;
  }
}

void *WMBagPrevious(WMBag *self, WMBagIterator *ptr)
{
  WMNode *node;

  if (*ptr == NULL)
    return NULL;

  node = treePredecessor(*ptr, self->sentinel);

  if (node == self->sentinel) {
    *ptr = NULL;
    return NULL;
  } else {
    *ptr = node;
    return node->data;
  }
}

void *WMBagIteratorAtIndex(WMBag *self, int index, WMBagIterator *ptr)
{
  WMNode *node;

  node = treeSearch(self->root, self->sentinel, index);

  if (node == self->sentinel) {
    *ptr = NULL;
    return NULL;
  } else {
    *ptr = node;
    return node->data;
  }
}

int WMBagIndexForIterator(WMBag *bag, WMBagIterator ptr)
{
  /* Parameter not used, but tell the compiler that it is ok */
  (void) bag;

  return ((WMNode *) ptr)->index;
}
