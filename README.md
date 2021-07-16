R code to download conference panels ('sessions') and papers from __[APSA meetings](https://apsanet.org/EVENTS/Past-Annual-Meetings) from 2015 to 2021__ (_T_ = __7 years__).

There are __9,772 sessions__ and __28,583 papers__, containing __15,974 unique participant names__ (with a few homonyms) and __3,652 unique affiliations__ (some of which point to the same entities).

| Year  | Sessions | Participants | Papers |
|:------|:-----|:-----|:-----|
| 2015 |  972 | 1,832 | 3,862 |
| 2016 | 1,131 | 2,240 | 4,127 |
| 2017 | 1,221 | 2,359 | 4,039 |
| 2018 | 1,294 | 6,559 | 4,202 |
| 2019 | 1,499 | 6,853 | 4,421 |
| 2020 | 1,301 | 5,705 | 3,480 |
| 2021 | 1,368 | 7,016 | 4,459 |

Running the download scripts takes roughly two days (the scripts leave 1.5 second between each download to avoid server choking).

## Data

`programs.tsv` contains all datasets below in a single (large) file.

- `papers.tsv` -- information on papers, identified by their `session` id ("session" means "conference panel") and `paper` id. Large file because it contains abstracts.
- `participants.tsv` -- information on participants (authors/presenters, chairs, discussants), identified by `pid`, their "person id". There are a few likely homonyms.
- `roles.tsv` -- the role of each participant (`pid`) in each panel (`session`): presenter (`p`, in which case the id of the presented paper is listed in `paper`), chair (`c`), discussant (`d`), or "else" (`e`) for very few special cases.
- `sessions.tsv` -- information on sessions (conference panels), identified by their `session` id.
- `years.tsv` -- a short summary of each conference year.

All files are TSV-formatted. Missing values are denoted `NA`.

Notes:

- Identifiers `session`, `paper` and `pid` are variable-length numbers, but are better handled by treating them as strings to avoid issues with e.g. leading zeros. - A few participants have two `pid` identifiers in a same conference year, most likely because they created two conference user accounts.
- Session and paper identifiers (`session` and `paper`) might repeat over years, which is why the data contain less unique values for those than listed above.
- Similarly, `pid` is unique only per conference year: it is *not* fixed through time, and so cannot be used to identify people longitudinally.

## Code

- Scripts 01-03 download the raw data, parse it, and create the datasets
- Scripts 04-05 sample conference panels, papers and participants

## Notes

On scraping the website interface:

- 2020 and 2021 require a time zone setting
- 2018 and 2019 use the 'new' All Academic Inc. interface
- 2016 and 2017 use the 'old' interface
- 2015 uses an even slightly 'older' interface that works exactly like the 'old' one

Main recurring session types for recent years, with counts:

|type                  |2018 |2019 |2020 |2021 (in-person) |2021 (virtual) |
|:---------------------|:----|:----|:----|:------|:------|
|Author meet critics   |59   |64   |59   |24     |27     |
|Business Meeting      |156  |140  |80   |12     |51     |
|Created Panel         |611  |641  |577  |319    |400    |
|Featured Paper Panel  |6    |9    |.   |1      |2      |
|Full Paper Panel      |376  |411  |334  |159    |141    |
|Poster Session        |58   |63   |52   |1      |65     |
|Reception             |77   |73   |25   |30     |11     |
|Roundtable            |137  |167  |127  |51     |87     |
|Short Course Full Day |14   |8    |2    |1      |.     |
|Short Course Half-Day |12   |12   |23   |9      |.     |
|TLC Full Paper Panel  |.   |1    |1    |5      |5      |
|TLC Workshop          |.   |2    |8    |3      |3      |

"TLC" means "Teaching and Learning Conference". There are many more session types, including some that were replaced by the "Created Panel" type in 2018.

## TODO

Other [candidate conferences](http://www.tulane.edu/~bbrox/confs.html):

- [MPSA](https://www.mpsanet.org/events/past-conference-programs/) (All Academic Inc.)
- [SPSA](https://spsa.net/annual-meeting/past-conference-programs/) (PDFs)
- [WPSA](https://www.wpsanet.org/meeting/) (own website, has participant emails)
- [SWPSA](https://sssaonline.org/affiliates/southwestern-political-science-association/annual-meeting/) (All Academic Inc. for some years, PDFs otherwise)
- [NPSA](https://www.northeasternpsa.com/past-conference-programs/) (All Academic Inc.)
- [NEPSA](https://www.nepsanet.org/conferenceprogramarchive) (PDFs)
- [PNWPSA](https://foley.wsu.edu/pnwpsa-meeting/) (PDF, no past archive)
- [SPPC](https://politicalscience.olemiss.edu/state-politics-and-policy-annual-conferences/) (different websites, some missing)
- [PolMeth](https://polmeth.org/conferences) (many different meetings, SPM one on different websites)

MPSA and NPSA might be doable, as might some years of SWPSA.
