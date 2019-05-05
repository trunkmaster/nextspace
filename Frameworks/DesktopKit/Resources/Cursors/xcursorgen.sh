#!/bin/sh

CURSORS_DIR="cursors"

rm ./cursors/*

echo "Generating cursor files in ./cursors directory..."
IFS=$'\n'
set -f
for i in $(cat < xcursorgen.conf); 
do
    IMAGE_FILE=`echo $i | awk '{print $4}'`
    CURSOR_FILE=`echo $IMAGE_FILE | awk -F/ '{print $2}'`
    CURSOR_FILE=`echo $CURSOR_FILE | awk -F. '{print $1}'`
    echo "$IMAGE_FILE -> $CURSORS_DIR/$CURSOR_FILE"
    echo $i | xcursorgen - $CURSORS_DIR/$CURSOR_FILE
done

echo "Generating animated cursors"
xcursorgen xanimcursor.conf $CURSORS_DIR/watch

echo "Creating links..."
cd $CURSORS_DIR
ln -s dnd-link alias
ln -s left_ptr arrow
ln -s sb_h_double_arrow col-resize
ln -s dnd-copy copy
ln -s cross cross_reverse
ln -s cross crosshair
ln -s left_ptr default
ln -s cross diamond_cross
ln -s sb_v_double_arrow double_arrow
ln -s right_ptr draft_large
ln -s right_ptr draft_small
ln -s right_side e-resize
ln -s sb_h_double_arrow ew-resize
ln -s grabbing fleur
ln -s hand1 grab
ln -s sb_h_double_arrow h_double_arrow
ln -s hand2 hand
ln -s question_arrow help
ln -s question_arrow left_ptr_help
ln -s top_side n-resize
ln -s top_right_corner ne-resize
ln -s fd_double_arrow nesw-resize
ln -s dnd-no-drop no-drop
ln -s crossed_circle not-allowed
ln -s sb_v_double_arrow ns-resize
ln -s top_left_corner nw-resize
ln -s bd_double_arrow nwse-resize
ln -s hand2 pointer
ln -s sb_v_double_arrow row-resize
ln -s bottom_side s-resize
ln -s bottom_right_corner se-resize
ln -s move size_all
ln -s fd_double_arrow size_bdiag
ln -s bd_double_arrow size_fdiag
ln -s sb_h_double_arrow size_hor
ln -s sb_v_double_arrow size_ver
ln -s bottom_left_corner sw-resize
ln -s xterm text
ln -s left_ptr top_left_arrow
ln -s sb_v_double_arrow v_double_arrow
ln -s left_side w-resize
ln -s watch wait
ln -s sb_v_double_arrow 00008160000006810000408080010102
ln -s sb_h_double_arrow 028006030e0e7ebffc7f7070c0600140
ln -s crossed_circle 03b6e0fcb3499374a867c041f52298f0
ln -s copy 1081e37283d90000800003c07f3ef6bf
ln -s sb_h_double_arrow 14fef782d02440884392942c11205230
ln -s sb_v_double_arrow 2870a09082c103050810ffdffffe0204
ln -s move 4498f0e0c1937ffe01fd06f973665830
ln -s question_arrow 5c6cd98b3f3ebcb1f9c7f1c204630408
ln -s copy 6407b0e94181790501fd1e167b474872
ln -s move 9081237383d90e509aa00f00170e968f
ln -s hand2 9d800788f1b08800ae810202380a0822
ln -s bd_double_arrow c7088f0f3e6c8088236ef8e1e3e70000
ln -s question_arrow d9ce0ab605698f320427677b458ad60b
ln -s hand2 e29285e634086352946a0e7090d73106
ln -s fd_double_arrow fcf1c3c7cd4491d801f1e1c78f100000
#ln -s left_ptr_watch 08e8e1c95fe2fc01f976f1e063a24ccd
#ln -s link 3085a0e285430894940527032f8b26df
#ln -s left_ptr_watch 3ecb610c1bf2410f44200f48c40d3599
#ln -s link 640fb0e74195791501fd1ed57b41487f
#ln -s left_ptr_watch progress
#ln -s dotbox dot_box_mask
#ln -s dotbox draped_box
#ln -s dotbox icon
#ln -s dotbox target
cd ..

echo "Generating NEXTSPACE cursor images..."
#24  4  4 ./images/dragCopy.png
convert ./images/dragCopy.png ../Images/dragCopyCursor.tiff
#24  5  5 ./images/dragLink.png
convert ./images/dragLink.png ../Images/dragLinkCursor.tiff
#24  7  5 ./images/dnd-move.png
convert ./images/dnd-move.png ../Images/dragMoveCursor.tiff
#24 11  8 ./images/resizeDown.png
#convert ./images/resizeDown.png ../Images/resizeDownCursor.tiff
#24 14 10 ./images/resizeLeft.png
#convert ./images/resizeLeft.png ../Images/resizeLeftCursor.tiff
#24 10 10 ./images/resizeLeftRight.png
#convert ./images/resizeLeftRight.png ../Images/resizeLeftRightCursor.tiff
#24  7 11 ./images/resizeRight.png
#convert ./images/resizeRight.png ../Images/resizeRightCursor.tiff
#24 10 14 ./images/resizeUp.png
#convert ./images/resizeUp.png ../Images/resizeUpCursor.tiff
#24 10 10 ./images/resizeUpDown.png
#convert ./images/resizeUpDown.png ../Images/resizeUpDownCursor.tiff
