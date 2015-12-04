

typedef struct W_GeometryView WGeometryView;


WGeometryView *WCreateGeometryView(WMScreen *scr);

void WSetGeometryViewShownPosition(WGeometryView *gview, int x, int y);

void WSetGeometryViewShownSize(WGeometryView *gview,
                               unsigned width, unsigned height);





