# searchengine
**SearchEngine** is a tool written in Foxpro and to a small but decisive part in C. It implements heuristic matching of large databases by fuzzy criteria like addresses. The fundament of the heuristic is constituted in the registry, a dictionary containing the words of your data along with the occurences. An important word has a low occurrence while filler words have high occurrences. The tool allows to specify weights on your search fields (e.g. firm name, street, city), which, in conjunction with a threshold, define the basic search strategy. This strategy can be further refined by additional options managing weight distributions (log, softmax, offset), defining feedback of surplus words, activation of countermeassures for suspiciously large candidate list and so on. A pertinent search approach consists of multiple search runs. The first run should always be a basic search, defining the overall settings according to the data structure followed by several specialized runs taking the specifics of the data into account, e.g. missing address parts, misspellings, noise in the name field and so on. It is strongly advised to go through the manual and the presentation slides in the **doc** directory.

If you are not interested in the source code, ignore the **code** directory.

## Documentation
The documentaion can be found in the  **doc** directory. It consists of a presentation explaining the algorithm and major features and a manual.

## Prerequisites
Windows

## Getting started
* Copy the **SE** directory in your data directory.
* Start the **SearchEngine.exe** to bring up a graphical user interface.
* Follow the instructions of the manual in the **doc** directory and browse through the slides.
* Your data has to be in tab-delimited text-format with header names und unique keys.
* The **data** directory contains two sample files to train your matching skills.
* You will need a **SE** directory for every dataset constituting the base of a search project.

## Version history

2022.03.10 SearchEngine 20.217
- slight improvement of the meta export performance

2022.02.22 SearchEngine 20.216
- fixed a bug, where the identity range selection of Result Export returned empty tables

2022.02.07 SearchEngine 20.215
- support for double encoded UTF-8 sequences in imported text files
- removed the "fast" option from the import options due to ensure consistent imports

2021.11.11 SearchEngine 20.214
- fixed a bug in single process refine
- fixed some progress messages
- better recognition of numbers in imported text files 

2021.09.22 SearchEngine 20.213
- the path of the BaseTable can now contain blanks without causing an exception (this error caused the influx of version changes)

2021.09.21 SearchEngine 20.212
- changed SORTLIMIT back to 100000000 (overflows are not the culprit of reported errors)
- error messages report proper exception descriptions 

2021.09.16 SearchEngine 20.211
- reduced SORTLIMIT from 100000000 to 50000000 to prevent sort space overflows
- progress bar does not switch to float numbers

2021.02.03 SearchEngine 20.21
- fixed a bug in Result Export preventing the combination of filtering and sample drawing
- Mirroring does not get stuck in a clean up process anymore

2020.12.08 SearchEngine 20.20.2
- minor adjustments to messages displayed during search

2020.11.30 SearchEngine 20.20.1
- fixed a bug in the multiprocessing control
- minor GUI adjustments

2020.11.12 SearchEngine 20.20
- MAJOR OVERHAUL of the SearchEngine introducing multiprocessing using the https://github.com/VFPX/ParallelFox package by Joel Leach
- unleash the power of your multicore environment: all functions support multiprocessing boosting the speed manyfold
- script language supports parameters and has new commands
- improved MetaExport format
- SEML directory contains sample code showing how to implement a ML algorithm based on https://github.com/ThorstenDoherr/brain Stata package and the Meta format
- new logo and icon

2020.04.09 SearchEngine 19.13
- greatly reduced memory consumption of the research function
- ExtendedExport allows the specification of implicit group keys \[in rectangular brackets\] to support grouping in conjunction with meta exports

2020.01.15 SearchEngine 19.11
- expanded Meta Export format to include information of the relative position within candidates
- fixed a bug in Meta Export pertaining run filter selection
- simplified field selection syntax in Meta Export format to prevent potential conflicts with the run filter specification
- you can now specifiy the temporary file directory in Preferences (saved in config.fpw; restart required)
- the default file extension can be switched between ".dbf" and ".txt" in Preferences (default = ".txt") with direct effect on file selection dialogs
- implemented tolerance to slight numeric discrepancies caused by the internal representation preventing omitted candidates on the threshold

2019.11.14 SearchEngine 19.00
- removed the requirement for unique keys by allowing record numbers for all exports
- new function Result Export creates filtered subsets and/or samples of the result table to temporarily or permanently replace it
- the new Meta Export format can be used for machine learning approaches
- complete overhaul of the more complex commands of the script language to reduce the number of required parameters
- fix of a potential memory leak affecting searches

2019.06.19 SearchEngine 18.20
- score is now independent of smoothing
- new smoothing/accentuating method using softmax function
- improved expand option by adding more ways to merge the occurrences of the search table and a rebuild function
		
2019.04.25 SearchEngine 18.12
- fixed a bug where the refine option ignored the run filter (GUI only)
- adjusted the size of the GroupedExport dialog
- manual is now a separate document
- updated manual and presentation

2018.11.19 SearchEngine 18.11
- improved internal sorting is faster and supports higher search depths 
- search depth still defaults to 262144 (depth = 0), but allows a maximum of 1048576
- maximum number of words is increased from 1024 to 2048
- if preferences have the default value, they are not displayed in the structure string

2018.08.14 SearchEngine 18.01
- record number of the seclected entry is now displayed as part of the heuristic information window

2018.05.28 SearchEngine 18.00
- new cascade parameters: s = score, p = percentile of score (see documentation)
- changes to GroupedExport dialog to accomodate new cascade parameters
- reworked File Locations dialog
- all activities within the GUI are logged to searchengine.log in the searchengine directory as script commands
- batch mode based on SearchEngine script commands (see documentation)
- delivery directory structure changed (SearchEngine files in SE sub-directory)
- introducing special preparer for german firms and street names as plug-in (searchengine.xml)
		
2018.03.27 SearchEngine 17.12
- bugfix for the mirror option

2017.09.14 SearchEngine 17.11
- bugfix for research exception
		
2017.08.30 SearchEngine 17.10
- included the "mirror" option under action to guarantee bi-directional matches (see documentation)
- improved stability for very large base tables
	
2017.06.01 SearchEngine 17.00
- tab-delimited text file support for "File locations" and all exports
- bugfix regarding the handling of long words in search term
- changed the size of many dialogs
- removed depreciated dialogs "AutoChecker" and "ResultAnalyser"
- new "Browser" dialog in "tools" to peek into Foxpro tables
- exports now allow "Skip if results greate equal the maximum exits" for better export splits
- changed example in GroupedExport dialog
- improved QuickSearch dialog
- removed compatibility with depreciated result table format
- options in the search dialog for overwriting the last run
- option "continue a canceled search" does not increment the run counter
- removed "txt2fox.exe" from th package because the SearchEngine now handles text files
- removed "fox2txt.exe" from th package because the SearchEngine now handles text files

## Acknowledgements
Joel Leach [ParallelFox](https://github.com/VFPX/ParallelFox)

### Author
* **Thorsten Doherr** - [ZEW](https://www.zew.de/en/team/tdo/)
