namespace Boo.Ide

import System
import System.Collections.Generic
import Boo.Lang.Compiler.Ast
import Boo.Lang.PatternMatching
import Boo.Lang.Compiler.TypeSystem

class TokenLocation:
	public Name as string
	public File as string
	public Line as int
	public Column as int
	
	def constructor (name as string, file as string, line as int, column as int):
		Name = name
		File = file
		Line = line
		Column = column

class TargetLookup(DepthFirstVisitor):
	_filename as string
	_line as int
	_column as int
	_invocations as List[of MethodInvocationExpression]
	
	def constructor (filename as string, line as int, column as int):
		_filename = filename
		_line = line
		_column = column
		_invocations = List[of MethodInvocationExpression]()
		
	static def GetLexicalInfo (node as IEntity):
		if (node is null):
			# Console.WriteLine ("null entity!")
			return null
		if (typeof(IInternalEntity).IsAssignableFrom (node.GetType ())):
			return (node as IInternalEntity).Node.LexicalInfo
		if (typeof(ExternalMethod).IsAssignableFrom (node.GetType ())):
			# Console.WriteLine ("Dropping external method {0}", node.Name)
			return null
		if (typeof(Method).IsAssignableFrom (node.GetType ())):
			return (node as Method).LexicalInfo
		else:
			raise ArgumentException (string.Format ("Invalid node type: {0}", node.GetType ()), "node");
	
	[lock]
	def FindIn(root as Node) as TokenLocation:
		Visit(root)
		info = null as LexicalInfo
		match _invocations.Count:
			case 0:
				return null
			case 1:
				info = GetLexicalInfo (_invocations[0].Target.Entity)
				if (info is null): return null
				# Console.WriteLine ("Found {0}", _invocations[0].Target.Entity.Name)
				return TokenLocation (_invocations[0].Target.Entity.Name, info.FullPath, info.Line, info.Column)
			otherwise:
				def comparer(a as MethodInvocationExpression, z as MethodInvocationExpression):
					return a.LexicalInfo.Column.CompareTo (z.LexicalInfo.Column)
				_invocations.Sort (comparer)
				method = null as MethodInvocationExpression
				for i in _invocations:
					if i.LexicalInfo.Column > _column:
						if (method is null): return null
						info = GetLexicalInfo (method.Target.Entity)
						if (info is null): return null
						# Console.WriteLine ("Found {0}", method.Target.Entity.Name)
						return TokenLocation (method.Target.Entity.Name, info.FullPath, info.Line, info.Column)
					method = i
				info = GetLexicalInfo (method.Target.Entity)
				if (info is null): return null
				# Console.WriteLine ("Found {0}", method.Target.Entity.Name)
				return TokenLocation (method.Target.Entity.Name, info.FullPath, info.Line, info.Column)
			
	override def LeaveMethodInvocationExpression (node as MethodInvocationExpression):
		if node.LexicalInfo is null:
			# Console.WriteLine ("No lexical info!")
			return
		if not node.LexicalInfo.FullPath.Equals(_filename, StringComparison.OrdinalIgnoreCase):
			# Console.WriteLine ("{0} doesn't match {1}", node.LexicalInfo.FullPath, _filename)
			return
		if _line != node.LexicalInfo.Line:
			# Console.WriteLine ("{0} doesn't match {1}", node.LexicalInfo.Line, _line)
			return
		
		_invocations.Add (node)
