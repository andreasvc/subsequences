subsequences
============

Extract longest common subsequences from texts, along with frequencies.


Requirements:
-------------
- Python 2.7+  http://www.python.org (need headers, e.g. python-dev package)
- Cython       http://www.cython.org

For example, to install these dependencies and compile the code on Ubuntu,
issue the following commands:

    sudo apt-get install python-dev build-essential
    sudo pip install cython
    git clone git://github.com/andreasvc/subsequences.git
    cd subsequences
    make


Usage:
------

	python subseq.py text1 [text2 [text3 ... textn --batch dir]] [--all] [--debug]

    text1 and text2 are filenames, each file containing
    one sentence per line, words space separated.
    Output will be a list of the longest common subsequences found
    in each sentence pair, followed by its occurrence frequency and a tab.
	Note that the output is space separated, like the input. Gaps are
    represented by an empty token, and are thus marked by two consecutive
	spaces. When a single file is given, pairs of sequences <n, m> are
	compared, except for pairs <n, n>.

        --all       enable collection of all subsequences of maximum length;
                    by default an arbitrary longest subsequence is returned.
        --debug     dump charts with lengths of common subsequences.
        --batch dir compare text1 to an arbitrary number of other given texts,
                    and write the results to dir/A_B for file A compared to B.
        --bracket   input is in the form of bracketed trees:
                    (S (DT one) (RB per) (NN line))
        --pos       when --bracket is enabled, include POS tags with tokens.

Example:
--------

    ~/subsequences $ head text*
    ==> text1 <==
    In winter Hammerfest is a thirty-hour ride by bus from Oslo, though why anyone would want to go there in winter is a question worth considering.
    
    ==> text2 <==
    Through winter, rides between Oslo and Hammerfest use thirty hours up in a bus, though why travellers would select to ride there then might be pondered.

    ~/subsequences $ python subseq.py text1 text2
    Hammerfest  a  though why  would  to  there     1

