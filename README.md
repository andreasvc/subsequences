subsequences
============

- Extract longest common subsequences from texts, along with frequencies.
- Extract common substrings from parallel texts, produce table of indices.


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

	usage: subseq.py text1 [text2 [text3 ... textn --batch dir]] [OPTIONS]

	text1 and text2 are filenames, each file containing
	one sentence per line, words space separated.
	Output will be a list of the longest common subsequences found
	in each sentence pair, followed by a tab and its occurrence frequency.
	Note that the output is space separated, like the input. Gaps are
	represented by an empty token, and are thus marked by two consecutive
	spaces. When a single file is given, pairs of sequences <n, m> are
	compared, except for pairs <n, n>.

		--all          enable collection of all subsequences of maximum length;
					   by default an arbitrary longest subsequence is returned.
		--debug        dump charts with lengths of common subsequences.
		--batch dir    compare text1 to an arbitrary number of other given texts,
					   and write the results to dir/A_B for file A compared to B.
		--enc x        specify encoding of input texts [default: utf-8].
		--bracket      input is in the form of bracketed trees:
					   (S (DT one) (RB per) (NN line))
		--pos          when --bracket is enabled, include POS tags with tokens.
		--strfragment  sentences include START & STOP symbols, subsequences must
					   consist of 3 or more tokens, begin with at least 2 tokens.
		--parallel     read sentence aligned corpus and produce table of parallel
					   substrings and the sentence indices in which they occur.
		--limit x      read up to x sentences of each file.
		--minmatches x only consider substrings with at least x tokens.
		--lower        convert texts to lower case
		--filter x     only consider tokens matching regex x; e.g.: '(?u)[-\w]+$'
					   to match only unicode alphanumeric characters and dash.


Examples:
---------
LCS:
~~~~

    ~/subsequences $ head text*
    ==> text1 <==
    In winter Hammerfest is a thirty-hour ride by bus from Oslo, though why anyone would want to go there in winter is a question worth considering.
    
    ==> text2 <==
    Through winter, rides between Oslo and Hammerfest use thirty hours up in a bus, though why travellers would select to ride there then might be pondered.

    ~/subsequences $ python subseq.py text1 text2
    Hammerfest  a  though why  would  to  there     1

Parallel substrings:
~~~~~~~~~~~~~~~~~~~~
	~/subsequences $ head s t
	==> s <==
	I feel we will have to call it a day at this point .
	He would like us to adjourn the vote to the next part-session and call it a day for now .

	==> t <==
	Credo che a questo punto dobbiamo passare oltre .
	Il relatore chiede di rinviare la votazione alla prossima seduta e , per ora , di passare oltre .

    ~/subsequences $ python subseq.py --parallel --filter='(?u)[-\w]+$' s t
	0. I feel we will have to call it a day at this point
	1. He would like us to adjourn the vote to the next part-session and call it a day for now
	1:
		call it a day
			passare oltre	{0,1}
		to
			passare oltre	{0,1}
