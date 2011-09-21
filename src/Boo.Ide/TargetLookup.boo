namespace Boo.Ide

import System
import System.Linq
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
	public TypeName as string
	
	def constructor (node as Node):
		if not Init (node as MethodInvocationExpression):
			if not Init (node as TypeReference):
				raise ArgumentException (string.Format ("Unable to create TargetLocation from {0}", node.GetType ()))
			
	private def Init (reference as TypeReference) as bool:
		return false if reference is null
		
		if (reference.Entity isa IType):
			TypeName = reference.Entity.FullName
			# Console.WriteLine ("Initializing with reference {0}", reference.Entity.FullName)
		# Console.WriteLine ("Initializing with reference {0}", reference.Entity.GetType ())
		return true
		
	private def Init (invocation as MethodInvocationExpression) as bool:
		return false if (invocation is null or invocation.Target.Entity is null)
		
		info = GetLexicalInfo (invocation.Target.Entity)
		if (info is null):
			# ExternalMethod, populate MemberInfo
			if not (invocation.Target.Entity isa ExternalMethod):
				raise ArgumentException ("Unable to lookup method invocation", "invocation")
			MemberInfo = (invocation.Target.Entity as ExternalMethod).MemberInfo
			Name = MemberInfo.Name
			Parent = MemberInfo.DeclaringType.FullName
		else:
			# Normal method with lexical info
			Name = invocation.Target.Entity.Name
			Parent = FullNameToParent (invocation.Target.Entity.Name, invocation.Target.Entity.FullName)
			File = info.FullPath
			Line = info.Line
			Column = info.Column
		return true
		
	override def ToString () as string:
		return string.Format ("{0}:{1},{2} ({3} | {4})", File, Line, Column, MemberInfo, TypeName)
		

class TargetLookup(DepthFirstVisitor):
	_filename as string
	_line as int
	_column as int
	_nodes as List[of Node]
	
	def constructor (filename as string, line as int, column as int):
		_filename = filename
		_line = line
		_column = column
		_nodes = List[of Node]()
		
	[lock]
	def FindIn(root as Node) as TokenLocation:
		Visit(root)
		
		
		match _nodes.Count:
			case 0:
				return null
			case 1:
				return TokenLocation (_nodes[0])
			otherwise:
				_nodes.Sort ({ a as Node,z as Node | a.LexicalInfo.Column.CompareTo (z.LexicalInfo.Column) })
				node = _nodes.LastOrDefault ({ n | n.LexicalInfo.Column <= _column })
					
				return null if (node is null)
				return TokenLocation (node)
				
			
	override def LeaveMethodInvocationExpression (node as MethodInvocationExpression):
		return if not LocationMatches (node)
		_nodes.Add (node)
		
	override def OnSimpleTypeReference (node as SimpleTypeReference):
		return if not LocationMatches (node)
		_nodes.Add (node)
		# Console.WriteLine ("Adding type reference {0}", node.Name)
		
	private def LocationMatches (node as Node):
		if node.LexicalInfo is null:
			# Console.WriteLine ("No lexical info!")
			return false
		if not node.LexicalInfo.FullPath.Equals(_filename, StringComparison.OrdinalIgnoreCase):
			# Console.WriteLine ("{0} doesn't match {1}", node.LexicalInfo.FullPath, _filename)
			return false
		if _line != node.LexicalInfo.Line:
			# Console.WriteLine ("{0} doesn't match {1}", node.LexicalInfo.Line, _line)
			return false
		return true
		
static def GetLexicalInfo (node as IEntity):
	if (node is null):
		# Console.WriteLine ("null entity!")
		return null
	if (node isa IInternalEntity):
		return (node as IInternalEntity).Node.LexicalInfo
	if (node isa ExternalMethod):
		# Console.WriteLine ("Dropping external method {0}", node.Name)
		return null
	if (node isa Method):
		return (node as Method).LexicalInfo
	else:
		raise ArgumentException (string.Format ("Invalid node type: {0}", node.GetType ()), "node");
		
static def FullNameToParent (name as string, fullname as string):
	if (string.IsNullOrEmpty (name)): raise ArgumentException ("Name cannot be empty")
	if (fullname is null or fullname.Length <= name.Length or not fullname.Contains (name)): return name
	
	return fullname.Substring (fullname.LastIndexOf (name))
	
