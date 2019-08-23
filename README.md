[![goodtables.io](https://goodtables.io/badge/github/loleg/swiss-parl-wordtime.svg)](https://goodtables.io/github/loleg/swiss-parl-wordtime)

This repository contains code and open data from an analysis of speeches of Swiss politicians evaluated by [Beobachter magazine](https://en.wikipedia.org/wiki/Beobachter_(magazine)) together with Oleg Lavrovsky from the association [Opendata.ch](https://opendata.ch), as basis for the article [Im Bundeshaus reden Frauen weniger](https://www.beobachter.ch/politik/wahlen-2019/long-read/datenanalyse-im-bundeshaus-reden-frauen-weniger) (Tina Berg, Yves Demuth 18.07.2019)

_Data source:_ Parliamentary Services of the Federal Assembly, Bern

_Last update:_ May 9, 2019

[<img alt="DataHub" src="https://datahub.io/static/img/logo-cube.png" width="50"><br>DataHub preview](https://datahub.io/loleg/swiss-parl-wordtime/v/1)

## Background

On the topic of the 2019 national elections in Switzerland, we analyzed parliamentary speeches during sessions of the [National Council](https://www.parlament.ch/en/organe/national-council) and the [Council of States](https://www.parlament.ch/en/organe/council-of-states). The first three years of the current legislative period - between November 2015 and December 2018 - were taken into account. 

Our focus was strictly on political speeches. During this period, there were seven Presidents and Vice-Presidents of the Council of States, and six Presidents and Vice-Presidents of the National Council whose speaking time was not evaluated, since it included administrative content and therefore was not comparable to the other speeches. Several members of the Councils resigned or came in between 2015 and 2018: they were also not counted. They were likewise excluded from the analysis. 

The evaluation therefore takes into account the speeches of 39 Council of States members (5 women and 34 men) who spoke a total of 315 hours (~13 days), as well as 175 National Council members (56 women and 119 men), who spoke a total of 552 hours (~23 days). 

## Data

The video recordings were made by the parliamentary services and the transcripts are open to the public. Open data from the Parliamentary Services of the Federal Assembly was collected from the [Swiss Parliament Web Services](https://www.parlament.ch/en/services/open-data-webservices).

We initially used data previously aggregated by [Tony Bowden](https://github.com/tmtmtmtm) (mySociety), and automatically updated on the [morph.io platform](https://morph.io/tmtmtmtm/switzerland-parlament). This is a script that connects to the "old" Web Services endpoint. The data is up-to-date, however it is missing some attributes which we needed, that are only available in the "new" endpoint.

Additionally, these similar open data projects provided inspiration: [make.opendata.ch//parlament](http://make.opendata.ch/wiki/project:parlament), [douglas-watson/parl-scraping](https://github.com/douglas-watson/parl-scraping.git).

## Preparation

To reproduce the analysis, these general steps are involved which you can see in the [analysis notebook](scraper.ipynb):

- Update the metadata of Swiss politicians
- Collect transcripts for specified criteria (dates, format)
- Filter out transcripts according to specific rules (error correction)
- Aggregate the times and apply word count calculations
- Output the aggregated data
- Run some consistency checks

Follow the instructions at [julialang.org](https://julialang.org/) to install Julia development environment on your system as a first step. 

Then open a Julia console, and at the prompt press ] on your keyboard to enter the package manager (your prompt will change to `(v1.1) pkg>`). Then enter the following to install required packages:

```
add JSON
add HTTP
add CSV
add Dates
add DelimitedFiles
add DataFrames
add Feather
```

You now have all the dependencies, and should be able to run the `scraper.jl` script to generate the data. If you would like to explore the process in more detail, we suggest [installing IJulia](https://github.com/JuliaLang/IJulia.jl#installation) to explore the analysis in the Jupyter notebook. At the same prompt as above, run:

`add IJulia`

Then in your shell console, run `jupyter notebook`, to be able to run the code in this repository.

## License

### ODC-PDDL-1.0

This Data Package is made available under the Public Domain Dedication and License v1.0 whose full text can be found at: [opendatacommons.org](http://www.opendatacommons.org/licenses/pddl/1.0/)

### Notes

The [Terms of Use](https://www.parlament.ch/en/services/open-data-webservices) (parlament.ch) of the source dataset list three specific restrictions on public use of these data:

- this information may not be used in such a way that it gives the impression of being an official publication
- if this information is reproduced the source must be indicated as follows: «Parliamentary Services of the Federal Assembly, Bern»;
- the content of the information may not be altered;
- the date on which the information was downloaded must be clearly indicated.
