""" Longest common subsequence for two texts. """
import sys, os
from getopt import gnu_getopt, GetoptError
from _lcs import getsequences

USAGE = """usage: %s text1 text2 [--all] [--debug]
text1 and text2 are filenames, each file containting
one sentence per line, words space separated.
Output will be a list of the longest common subsequences found
in each sentence pair, preceded by its occurrence frequency and a tab.

    --all   enable collection of all longest common subsequences.
    --debug dump charts with lengths of common subsequences.
    --batch dir
            compare text1 to an arbitrary number of other given texts, and
            write the results to dir/A_B for file A compared to B.
    --quiet ignored
""" % sys.argv[0]

def main():
	# command line arguments
	flags = ("quiet", "debug", "all")
	options = ("batch=", )
	try:
		opts, args = gnu_getopt(sys.argv[1:], "", flags + options)
	except GetoptError as err:
		print "error: %r\n%s" % (err, USAGE)
		exit(2)
	opts = dict(opts)
	for filename in args:
		assert os.path.exists(filename), "file not found: %r" % filename
	if '--batch' not in opts:
		assert len(args) == 2, USAGE
		# dump subsequences to stdout
		outfile = sys.stdout
	else:
		assert len(args) >= 2, USAGE
	filename1 = args[0]
	for filename2 in args[1:]:
		# find subsequences
		results = getsequences(filename1, filename2,
			getall="--all" in opts)

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
