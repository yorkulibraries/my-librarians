my-librarians
=============

My Librarians is a web service that provides a personalized RSS feeds of subject librarians.  Given one or more course codes, it will check a Google Drive spreadsheet and returns lists of librarians (or, as a fallback, reference desks) that cover the relevant subject(s).

TODO: Offer feed of liaison libarians as well.

# Installation

My Librarians requires a recent Ruby and the Bundler gem.  If you don't have it already, run

    $ gem install bundler

Then:

    $ git clone git@github.com:yorkulibraries/my-librarians.git
    $ cd my-librarians
	$ cp config.json.example config.json
    $ bundle install
	$ bundle exec rackup config.ru

Edit the config file to suit your own needs, but it will work with the example and pull in what York University Libraries uses.

# Usage

    $ curl http://localhost:9292/subject?courses=2012_HH_PSYC_F_2030__3_A_EN_A_LECT_01,2012_SC_CSE_F_1710__3_A_EN_A_LAB_03
    $ curl http://localhost:9292/subject?tag=hh/psyc,ap/sosc

# Course codes and parameters

York University course codes are all listed at [http://coursecode.yorku.ca/](http://coursecode.yorku.ca/).

In full form they look like this: `2012_AP_IT_Y_2751__9_A_EN_A_LECT_01` (Roman Elegaic Poetry).

    Year           : 2012
    Faculty        : AP (Faculty of Liberal Arts and Professional Studies)
    Subject        : IT (Italian)
    Period         : Y (F = fall, W = winter, SU, S1, S2 = summer)
    ID             : 2751
    Rubric variance: _ (if it is blank, replace with an extra underscore)
    Credit weight  : 9
    Section        : A
    Language       : EN
    Course type    : A (internal code)
    Format         : LECT
    Group          : 01

Other good course codes to use:

* `2012_HH_PSYC_F_2030__3_A_EN_A_LECT_01` (Introduction to Research Methods)
* `2012_SC_CSE_F_1710__3_A_EN_A_LAB_03` (Programming for Digital Media).

When Eris calls a web service it passes over course codes in their complete form and also broken up into parts, like so:

    GET /something?
    courses=2012_AP_SOSC_Y_1341__9_A_EN_A_LECT_01
    &tag=SOSC_1341,AP/SOSC,AP/sosc1341,2012_AP_SOSC_Y_1341__9_A_EN_A_LECT_01
	&program_codes=SOSC_1341,AP/SOSC,AP/sosc1341`

The rule in My Librarians is that if courses is passed in (with one or more full course codes, comma-separated) it will be used exclusively and the other variables will be ignored because they are too messy. However, if tag exists alone (with one or more short-form tags, comma-separated), we will use it.

# Coverage

It's helpful to know which courses offered don't appear to have a subject librarian.  There is a file in `public` that is a CSV dump of all courses offered at York (currently, the 2012 fall and winter offerings). It looks like this:

    "fac","subj","crsnum","longtitle"
    "AP","ADMS",1000,"Introduction to Administrative Studies"
    "AP","ADMS",1010,"Business in the Canadian Context"

`coverage.rb` is a helper tool that will check that file against the Google Drive spreadsheet and report a list of all courses that don't seem to have a subject librarian.

It respects wildcards, but it may be useful to turn this off to give a more accurate picture of which students will see a librarian and which are being sent to a reference desk.

    $ ./coverage.rb > not-covered.txt
    Faculty/programs known: 244
    Subjects covered (including wildcards): 82
    Faculty/programs not covered: 79
    $ head -3 not-covered.txt 
    AP/ARB
    AP/ASL
    AP/CAW


