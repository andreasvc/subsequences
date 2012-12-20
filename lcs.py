""" Longest common subsequence for two texts. """
import sys, os
from getopt import gnu_getopt, GetoptError
from _lcs import Comparator

USAGE = """
usage: %s text1 [text2 [text3 ... textn --batch dir]] [--all] [--debug]

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
""" % sys.argv[0]

def main():
	""" Parse command line arguments, get subsequences, dump to stdout/file. """
	# command line arguments
	flags = ("debug", "all", "bracket", "pos")
	options = ("batch=", )
	try:
		opts, args = gnu_getopt(sys.argv[1:], "", flags + options)
		opts = dict(opts)
		if '--batch' not in opts:
			assert 1 <= len(args) <= 2, "wrong number of arguments"
			# dump subsequences to stdout
			outfile = sys.stdout
		else:
			assert len(args) >= 2, "wrong number of arguments"
		for n, filename in enumerate(args):
			assert os.path.exists(filename), "file %d not found: %r" % (
					n + 1, filename)
	except (GetoptError, AssertionError) as err:
		print err, USAGE
		return

	# read first text
	filename1 = args[0]
	comparator = Comparator(filename1,
			bracket="--bracket" in opts, pos="--pos" in opts)

	# find subsequences
	if len(args) == 1:
		results = comparator.getsequences(None,
				getall="--all" in opts, debug="--debug" in opts)
		outfile.writelines("%s\t%d\n" % (" ".join(subseq), count)
				for subseq, count in results.iteritems())
	else:
		for filename2 in args[1:]:
			results = comparator.getsequences(filename2,
					getall="--all" in opts, debug="--debug" in opts)

			if '--batch' in opts:
				# dump subsequences to file in given directory
				outfile = open("%s/%s_%s" % (opts['--batch'],
					os.path.basename(filename1),
					os.path.basename(filename2)), "w")
			outfile.writelines("%s\t%d\n" % (" ".join(subseq), count)
					for subseq, count in results.iteritems())
			if '--batch' in opts:
				outfile.close()

if __name__ == '__main__':
	main()
