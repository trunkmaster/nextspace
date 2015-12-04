
/*
 * Header for demo widget.
 *
 */

typedef struct W_MyWidget MyWidget;


MyWidget *CreateMyWidget(WMWidget *parent);

void SetMyWidgetText(MyWidget *mPtr, char *text);

W_Class InitMyWidget(WMScreen *scr);

