/* diamond mark */
#define MENU_RADIO_INDICATOR_XBM_SIZE 9
static unsigned char MENU_RADIO_INDICATOR_XBM_DATA[] = {
    0x10, 0x00, 0x38, 0x00, 0x7c, 0x00, 0xee, 0x00, 0xc7, 0x01, 0xee, 0x00,
    0x7c, 0x00, 0x38, 0x00, 0x10, 0x00};

/* check mark */
#define MENU_CHECK_INDICATOR_XBM_SIZE 9
static unsigned char MENU_CHECK_INDICATOR_XBM_DATA[] = {
    0x00, 0x01, 0x83, 0x01, 0xc3, 0x00, 0x63, 0x00, 0x33, 0x00, 0x1b, 0x00,
    0x0f, 0x00, 0x07, 0x00, 0x03, 0x00};

#define MENU_MINI_INDICATOR_XBM_SIZE 9
static unsigned char MENU_MINI_INDICATOR_XBM_DATA[] = {
    0xff, 0x01, 0xff, 0x01, 0xff, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x01, 0x01, 0x01, 0x01, 0xff, 0x01};

#define MENU_HIDE_INDICATOR_XBM_SIZE 9
static unsigned char MENU_HIDE_INDICATOR_XBM_DATA[] = {
    0x99, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x01, 0x00,
    0x00, 0x00, 0x00, 0x01, 0x33, 0x01};

#define MENU_SHADE_INDICATOR_XBM_SIZE 9
static unsigned char MENU_SHADE_INDICATOR_XBM_DATA[] = {
    0xff, 0x01, 0xff, 0x01, 0xff, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00};



/* button pixmaps */
/* the first one is for normal state, the second is for when
 * the button is pushed */
static char *PRED_CLOSE_XPM[] = {
    "10 10 3 1",
    " 	c #000000",
    ".	c #616561",
    "X	c None",
    " .XXXXXX. ",
    ". .XXXX. .",
    "X. .XX. .X",
    "XX. .. .XX",
    "XXX.  .XXX",
    "XXX.  .XXX",
    "XX. .. .XX",
    "X. .XX. .X",
    ". .XXXX. .",
    " .XXXXXX. "};


static char *PRED_BROKEN_CLOSE_XPM[] = {
    "10 10 3 1",
    " 	c #000000",
    ".	c #616561",
    "X	c None",
    " .XXXXXX. ",
    ". .XXXX. .",
    "X. XXXX .X",
    "XXXXXXXXXX",
    "XXXXXXXXXX",
    "XXXXXXXXXX",
    "XXXXXXXXXX",
    "X. XXXX .X",
    ". .XXXX. .",
    " .XXXXXX. "};


static char *PRED_KILL_XPM[] = {
    "10 10 3 1",
    " 	c #000000",
    ".	c #616561",
    "X	c None",
    " .XXXXXX. ",
    ". XXXXXX .",
    "XXXXXXXXXX",
    "XXX .. XXX",
    "XXX.  .XXX",
    "XXX.  .XXX",
    "XXX .. XXX",
    "XXXXXXXXXX",
    ". XXXXXX .",
    " .XXXXXX. "};


static char *PRED_ICONIFY_XPM[] = {
    "    10    10        2            1",
    ". c #000000",
    "# c None",
    "..........",
    "..........",
    "..........",
    ".########.",
    ".########.",
    ".########.",
    ".########.",
    ".########.",
    ".########.",
    ".........."
};

