
#ifndef _TABLEDELEGATES_H_
#define _TABLEDELEGATES_H_

#ifdef __cplusplus
extern "C" {
#endif

WMTableColumnDelegate *WTCreatePixmapDelegate(WMTableView *table);
WMTableColumnDelegate *WTCreateStringDelegate(WMTableView *table);
WMTableColumnDelegate *WTCreatePixmapStringDelegate(WMTableView *parent);

WMTableColumnDelegate *WTCreateStringEditorDelegate(WMTableView *table);
    
WMTableColumnDelegate *WTCreateEnumSelectorDelegate(WMTableView *table);
void WTSetEnumSelectorOptions(WMTableColumnDelegate *delegate,
                              char **options, int count);
    
WMTableColumnDelegate *WTCreateBooleanSwitchDelegate(WMTableView *parent);
    
#ifdef __cplusplus
}
#endif
    
#endif
