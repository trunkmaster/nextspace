/* ---[ WINGs/tree.c ]---------------------------------------------------- */

#ifndef _WTREE_H_
#define _WTREE_H_

#include <WMcore/WMcore.h>

typedef struct W_TreeNode WMTreeNode;
typedef void WMTreeWalkProc(WMTreeNode *aNode, void *data);

/* Generic Tree and TreeNode */

WMTreeNode* WMCreateTreeNode(void *data);

WMTreeNode* WMCreateTreeNodeWithDestructor(void *data, WMFreeDataProc *destructor);

WMTreeNode* WMInsertItemInTree(WMTreeNode *parent, int index, void *item);

#define WMAddItemToTree(parent, item)  WMInsertItemInTree(parent, -1, item)

WMTreeNode* WMInsertNodeInTree(WMTreeNode *parent, int index, WMTreeNode *aNode);

#define WMAddNodeToTree(parent, aNode)  WMInsertNodeInTree(parent, -1, aNode)

void WMDestroyTreeNode(WMTreeNode *aNode);

void WMDeleteLeafForTreeNode(WMTreeNode *aNode, int index);

void WMRemoveLeafForTreeNode(WMTreeNode *aNode, void *leaf);

void* WMReplaceDataForTreeNode(WMTreeNode *aNode, void *newData);

void* WMGetDataForTreeNode(WMTreeNode *aNode);

int WMGetTreeNodeDepth(WMTreeNode *aNode);

WMTreeNode* WMGetParentForTreeNode(WMTreeNode *aNode);

/* Sort only the leaves of the passed node */
void WMSortLeavesForTreeNode(WMTreeNode *aNode, WMCompareDataProc *comparer);

/* Sort all tree recursively starting from the passed node */
void WMSortTree(WMTreeNode *aNode, WMCompareDataProc *comparer);

/* Returns the first node which matches node's data with cdata by 'match' */
WMTreeNode* WMFindInTree(WMTreeNode *aTree, WMMatchDataProc *match, void *cdata);

/* Returns the first node where node's data matches cdata by 'match' and node is
 * at most `limit' depths down from `aTree'. */
WMTreeNode *WMFindInTreeWithDepthLimit(WMTreeNode * aTree, WMMatchDataProc * match, void *cdata, int limit);

/* Returns first tree node that has data == cdata */
#define WMGetFirstInTree(aTree, cdata) WMFindInTree(aTree, NULL, cdata)

/* Walk every node of aNode with `walk' */
void WMTreeWalk(WMTreeNode *aNode, WMTreeWalkProc * walk, void *data, Bool DepthFirst);

#endif
