""" Longest common subsequence for two texts. """
import sys, os
from _lcs import getsequences

USAGE = """usage: %s text1 text2 [--all] [--debug]
text1 and text2 are filenames, each file containting
one sentence per line, words space separated.
Output will be a list of the longest common subsequences found
in each sentence pair, preceded by its occurrence frequency and a tab.

	--all	enable collection of all longest common subsequences.
	--debug	dump chart with lengths of common subsequences for two sequences.
""" % sys.argv[0]

def main():
	# command line arguments
	if len(sys.argv) < 3:
		print USAGE
	elif not os.path.exists(sys.argv[1]):
		print "file not found:", sys.argv[1]
	elif not os.path.exists(sys.argv[2]):
		print "file not found:", sys.argv[2]
	else:
		# find subsequences
		results = getsequences(sys.argv[1], sys.argv[2],
				getall="--all" in sys.argv, debug="--debug" in sys.argv)

		# dump subsequences to stdout
		for subseq, count in results.iteritems():
			print "%d\t%s" % (count, " ".join(subseq))

if __name__ == '__main__':
	main()
