subsequences
============

Extract longest common subsequences from texts.


Requirements:
-------------
- Python 2.7+  http://www.python.org (need headers, e.g. python-dev package)
- Cython       http://www.cython.org
- GCC          http://gcc.gnu.org

For example, to install these dependencies and compile the code on Ubuntu,
issue the following commands:

    sudo apt-get install python-dev build-essential
    sudo pip install cython
    git clone git://github.com/andreasvc/subsequences.git
    cd subsequences
    make


Usage:
------

    python lcs.py text1 text2 [text3 ... textn --batch dir] [--all] [--debug]

    text1 and text2 are filenames, each file containting
    one sentence per line, words space separated.
    Output will be a list of the longest common subsequences found
    in each sentence pair, preceded by its occurrence frequency and a tab.

        --all       enable collection of all longest common subsequences.
        --debug     dump charts with lengths of common subsequences.
        --batch dir compare text1 to an arbitrary number of other given texts,
                    and write the results to dir/A_B for file A compared to B.
        --bracket   input is in the form of bracketed trees:
                    (S (DT one) (RB per) (NN line))
        --pos       when --bracket is enabled, include POS tags with tokens.

