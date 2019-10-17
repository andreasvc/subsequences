""" Longest common subsequence for two texts. """
from __future__ import print_function, division
import os
import sys
import itertools
from getopt import gnu_getopt, GetoptError
from lcs import LCSComparator
from parallelsubstr import ParallelComparator

USAGE = """
usage: %s text1 [text2 [text3 ... textn --batch dir]] [OPTIONS]

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
    --dist         compute LCS-distances for all pairs of sentences.
    --debug        dump charts with lengths of common subsequences.
    --batch dir    compare text1 to an arbitrary number of other given texts,
                   and write the results to dir/A_B for file A compared to B.
    --enc x        specify encoding of input texts [default: utf-8].
    --bracket      input is in the form of bracketed trees:
                   (S (DT one) (RB per) (NN line))
    --pos          when --bracket is enabled, include POS tags with tokens.
	--chars        character-based instead of token-based comparison.
    --strfragment  sentences include START & STOP symbols, subsequences must
                   consist of 3 or more tokens, begin with at least 2 tokens.
    --parallel     read sentence aligned corpus and produce table of parallel
                   substrings and the sentence indices in which they occur.
    --limit x      read up to x sentences of each file.
    --minmatches x only consider substrings with at least x tokens.
    --lower        convert texts to lower case
    --filter x     only consider tokens matching regex x; e.g.: '(?u)[-\\w]+$'
                   to match only unicode alphanumeric characters and dash.

""" % sys.argv[0]


def main():
	"""Parse command line arguments, get subsequences, dump to stdout/file."""
	# command line arguments
	flags = ('debug', 'all', 'dist', 'bracket', 'pos', 'chars',
			'strfragment', 'parallel', 'lower')
	options = ('batch=', 'limit=', 'minmatches=', 'filter=', 'enc=')
	try:
		opts, args = gnu_getopt(sys.argv[1:], '', flags + options)
		opts = dict(opts)
		if '--batch' not in opts:
			assert 1 <= len(args) <= 2, "wrong number of arguments"
			# dump subsequences to stdout
			outfile = sys.stdout
		else:
			assert len(args) >= 2, "wrong number of arguments"
		for n, filename in enumerate(args):
			assert os.path.exists(filename), (
					"file %d not found: %r" % (n + 1, filename))
	except (GetoptError, AssertionError) as err:
		print(err, USAGE)
		return

	# read first text
	filename1 = args[0]
	limit = int(opts['--limit']) if '--limit' in opts else None
	filterre = opts['--filter'] if '--filter' in opts else None
	sep = '' if '--chars' in opts else ' '
	if '--parallel' in opts:
		comparator = ParallelComparator(
				filename1,
				encoding=opts.get('--enc', 'utf8'),
				bracket='--bracket' in opts,
				pos='--pos' in opts,
				chars='--chars' in opts,
				strfragment='--strfragment' in opts,
				lower='--lower' in opts,
				limit=limit,
				filterre=filterre)
		table = comparator.getsequences(
				args[1],
				minmatchsize=int(opts.get('--minmatches', 1)),
				debug='--debug' in opts)
		comparator.dumptable(table, outfile)
		return

	comparator = LCSComparator(
			filename1,
			encoding=opts.get('--enc', 'utf8'),
			bracket='--bracket' in opts,
			pos='--pos' in opts,
			chars='--chars' in opts,
			strfragment='--strfragment' in opts,
			lower='--lower' in opts,
			limit=limit,
			filterre=filterre)

	# find subsequences
	if '--dist' in opts:
		if len(args) > 2 or '--batch' in opts:
			raise NotImplementedError
		dists = comparator.getdistances(None if len(args) == 1 else args[1],
				debug='--debug' in opts)
		import numpy as np
		outfile.writelines('%d\t%d\t%g\n' % (n, m, dist)
				for (n, m), dist in np.ndenumerate(dists)
				if dist != -1)
		return
	if len(args) == 1:
		results = comparator.getsequences(None,
				getall='--all' in opts, debug='--debug' in opts)
		outfile.writelines("%s\t%d\n" % (sep.join(subseq), count)
				for subseq, count in results.iteritems())
	else:
		for filename2 in args[1:]:
			results = comparator.getsequences(filename2,
					getall='--all' in opts, debug='--debug' in opts)

			if '--batch' in opts:
				# dump subsequences to file in given directory
				outfile = open("%s/%s_%s" % (opts['--batch'],
					os.path.basename(filename1),
					os.path.basename(filename2)), 'w')
			outfile.writelines("%s\t%d\n" % (sep.join(subseq), count)
					for subseq, count in results.items())
			if '--batch' in opts:
				outfile.close()


if __name__ == '__main__':
	main()
