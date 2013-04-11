my-librarians
=============

My Librarians is a web service that provides a personalized RSS feeds of subject librarians.  Given one or more course codes, it will check a Google Drive spreadsheet and returns lists of librarians (or, as a fallback, reference desks) that cover the relevant subject(s).

TODO: Offer feed of liaison libarians as well.

# Installation



# Usage:

    /subject?courses=2012_HH_PSYC_F_2030__3_A_EN_A_LECT_01,2012_SC_CSE_F_1710__3_A_EN_A_LAB_03

    /subject?tag=hh/psyc,ap/sosc

Course codes look like this (for "Romain Elegaic Poetry"): `2012_AP_IT_Y_2751__9_A_EN_A_LECT_01`

    Year           : 2012
    Faculty        : AP
    Subject        : IT
    Period         : Y (F = fall, W = winter, SU, S1, S2 = summer)
    ID             : 2751
    Rubric variance: _ (if it is blank, replace with an extra underscore)
    Credit weight  : 9
    Section        : A
    Language       : EN
    Course type    : A (internal code)
    Format         : LECT
    Group          : 01

Other good course codes: `2012_HH_PSYC_F_2030__3_A_EN_A_LECT_01` (Introduction to Research Methods) and `2012_SC_CSE_F_1710__3_A_EN_A_LAB_03` (Programming for Digital Media).

# Eris and variables passed in

When Eris calls a web service it passes over course codes in their
complete form and also broken up into parts, like so:

"GET /something?
courses=2012_AP_SOSC_Y_1341__9_A_EN_A_LECT_01
&tag=SOSC_1341,AP/SOSC,AP/sosc1341,2012_AP_SOSC_Y_1341__9_A_EN_A_LECT_01
&program_codes=SOSC_1341,AP/SOSC,AP/sosc1341

The rule here is that if courses is passed in, we will use it exclusively and ignore other variables, which are messy. However, if tag exists alone, we will use it.

