
#define WHITE "^0"
#define BLUE "^1"
#define RED "^2"
#define YELLOW "^3"
#define GREY "^4"
#define GRAY GREY
#define GREEN "^5"
#define POP "^<"

#define ALPHA100 "^#"
#define ALPHA50 "^$"
#define ALPHA25 "^%"

/* there are some non-ascii symbols in the font */
#define CHECKMARK "\xF2"
#define ESC "\xF3"
#define HEART "\xF4"
/* here L means "long" */
#define LCMARK1 "\xF5"
#define LCMARK2 "\xF6"
#define LCHECKMARK LCMARK1 LCMARK2
#define LRARROW1 "\xF7"
#define LRARROW2 "\xF8"
#define LRARROW LRARROW1 LRARROW2
#define LLARROW1 "\xF9"
#define LLARROW2 "\xFA"
#define LLARROW LLARROW1 LLARROW2

/* BAR_0 ... BAR_10 are guaranteed to be consecutive */
#define BAR_0 "\xE0"
#define BAR_1 "\xE1"
#define BAR_2 "\xE2"
#define BAR_3 "\xE3"
#define BAR_4 "\xE4"
#define BAR_5 "\xE5"
#define BAR_6 "\xE6"
#define BAR_7 "\xE7"
#define BAR_8 "\xE8"
#define BAR_9 "\xE9"
#define BAR_10 "\xEA"
#define BARSTART "\xEB"

#define FONTCHARS " ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789`-=[]\\;',./~!@#$%^&*()_+{}|:\"<>?" CHECKMARK ESC HEART LCMARK1 LCMARK2 BAR_0 BAR_1 BAR_2 BAR_3 BAR_4 BAR_5 BAR_6 BAR_7 BAR_8 BAR_9 BAR_10 BARSTART LRARROW LLARROW


/* additionally, one style just holds little helper
   images instead of letters */
#define PICS "^6"

/* small, yellow colored arrows */
#define ARROWR "A"
#define ARROWU "B"
#define ARROWD "C"
#define ARROWL "D"
/* exclamation icon */
#define EXCICON1 "E"
#define EXCICON2 "F"
#define EXCICON EXCICON1 EXCICON2
#define SKULLICON1 "G"
#define SKULLICON2 "H"
#define SKULLICON SKULLICON1 SKULLICON2
/* thumbs up */
#define THUMBICON1 "I"
#define THUMBICON2 "J"
#define THUMBICON THUMBICON1 THUMBICON2
#define BUGICON1 "K"
#define BUGICON2 "L"
#define BUGICON BUGICON1 BUGICON2
#define QICON1 "M"
#define QICON2 "N"
#define QICON QICON1 QICON2
#define XICON1 "O"
#define XICON2 "P"
#define XICON XICON1 XICON2
#define BARLEFT "Q"
#define BAR "R"
#define BARRIGHT "S"
#define SLIDELEFT "T"
#define SLIDE "U"
#define SLIDERIGHT "V"
#define SLIDEKNOB "W"
#define TRASHCAN1 "X"
#define TRASHCAN2 "Y"
#define TRASHCAN TRASHCAN1 TRASHCAN2
#define KEYPIC1 "Z"
#define KEYPIC2 "a"
#define KEYPIC KEYPIC1 KEYPIC2
#define BOOKMARKPIC1 "b"
#define BOOKMARKPIC2 "c"
#define BOOKMARKPIC3 "d"
#define BOOKMARKPIC BOOKMARKPIC1 BOOKMARKPIC2 BOOKMARKPIC3

#define FONTSTYLES 7

