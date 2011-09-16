namespace Boo.Ide

import System
import System.Reflection
import System.Collections.Generic
import Boo.Lang.Compiler.Ast
import Boo.Lang.PatternMatching
import Boo.Lang.Compiler.TypeSystem

class TokenLocation:
	public Name as string
	public Parent as string
	public File as string
	public Line as int
	public Column as int
	public MemberInfo as MemberInfo
	
	def constructor (entity as MethodInvocationExpression):
		if (entity.Target.Entity is null):
			# Console.WriteLine ("Null target for {0}", entity)
			raise ArgumentException ("Unable to lookup method invocation", "entity")
		info = GetLexicalInfo (entity.Target.Entity)
		if (info is null):
			if not (typeof (ExternalMethod).IsAssignableFrom (entity.Target.Entity.GetType ())):
				raise ArgumentException ("Unable to lookup method invocation", "entity")
			MemberInfo = (entity.Target.Entity as ExternalMethod).MemberInfo
			Name = MemberInfo.Name
			Parent = MemberInfo.DeclaringType.FullName
		else:
			Name = entity.Target.Entity.Name
			Parent = FullNameToParent (entity.Target.Entity.Name, entity.Target.Entity.FullName)
			File = info.FullPath
			Line = info.Line
			Column = info.Column

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
		
	[lock]
	def FindIn(root as Node) as TokenLocation:
		Visit(root)
		match _invocations.Count:
			case 0:
				return null
			case 1:
				return TokenLocation (_invocations[0])
			otherwise:
				_invocations.Sort ({ a as MethodInvocationExpression,z as MethodInvocationExpression | a.LexicalInfo.Column.CompareTo (z.LexicalInfo.Column) })
				method = null as MethodInvocationExpression
				for i in _invocations:
					if i.LexicalInfo.Column > _column:
						if (method is null): return null
						return TokenLocation (method)
					method = i
				return TokenLocation (method)
			
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
		
static def FullNameToParent (name as string, fullname as string):
	if (string.IsNullOrEmpty (name)): raise ArgumentException ("Name cannot be empty")
	if (fullname is null or fullname.Length <= name.Length or not fullname.Contains (name)): return name
	
	return fullname.Substring (fullname.LastIndexOf (name))
	
