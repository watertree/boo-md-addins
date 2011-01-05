namespace Boo.Ide.Tests

import System.Linq.Enumerable

def SystemObjectMemberNames():
	return "Equals", "GetHashCode", "GetType", "ToString"
	
def ReIndent(code as string):	
	lines = code.Replace("\r\n", "\n").Split(char('\n'))
	nonEmptyLines = line for line in lines if len(line.Trim())

	indentation = /(\s*)/.Match(nonEmptyLines.First()).Groups[0].Value
	return code if len(indentation) == 0

	buffer = System.Text.StringBuilder()
	for line in lines:
		if line.StartsWith(indentation):
			buffer.AppendLine(line[len(indentation):])
		else:
			buffer.AppendLine(line)
	return buffer.ToString()