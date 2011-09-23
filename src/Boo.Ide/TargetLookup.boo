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
		initialized = false
		if node isa MethodInvocationExpression:
			initialized = Init (node as MethodInvocationExpression)
		elif node isa TypeReference:
			initialized = Init (node as TypeReference)
		elif node isa MemberReferenceExpression:
			initialized = Init (node as MemberReferenceExpression)
				
		if not initialized:
			raise ArgumentException (string.Format ("Unable to create TargetLocation from {0}", node.GetType ()))
			
	private def Init (reference as TypeReference) as bool:
		return false if reference is null
		
		if (reference.Entity isa IType):
			TypeName = reference.Entity.FullName
			# Console.WriteLine ("Initializing with reference {0}", reference.Entity.FullName)
		# Console.WriteLine ("Initializing with reference {0}", reference.Entity.GetType ())
		return true
		
	private def Init (invocation as MethodInvocationExpression) as bool:
		return false if (invocation is null or invocation.Target is null or invocation.Target.Entity is null)
		ReadEntity (invocation.Target.Entity)
		return true
		
	private def Init (reference as MemberReferenceExpression):
		return false if (reference is null or reference.Entity is null)
		# Console.WriteLine (reference.Entity)
		ReadEntity (reference.Entity)
		return true
		
	private def ReadEntity(entity as IEntity):
		info = GetLexicalInfo (entity)
		if (info is null):
			# ExternalEntity, populate MemberInfo
			if not (entity isa IExternalEntity):
				raise ArgumentException ("Unable to lookup entity", "entity")
			MemberInfo = (entity as IExternalEntity).MemberInfo
			Name = MemberInfo.Name
			Parent = MemberInfo.DeclaringType.FullName
		else:
			# Normal member with lexical info
			Name = entity.Name
			Parent = FullNameToParent (entity.Name, entity.FullName)
			File = info.FullPath
			Line = info.Line
			Column = info.Column
		
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
				# for node in _nodes:
				# 	Console.WriteLine ("Checking {0}({1}) against {2}", node, node.LexicalInfo, _column)
				node = _nodes.LastOrDefault ({ n | n.LexicalInfo.Column <= _column })
					
				return null if (node is null)
				# Console.WriteLine ("Using {0} ({1})", node.Entity, node.GetType())
				return TokenLocation (node)
				
			
	override def LeaveMethodInvocationExpression (node as MethodInvocationExpression):
		# Console.WriteLine ("Checking {0}", node)
		return if not LocationMatches (node)
		_nodes.Add (node)
		
	override def OnSimpleTypeReference (node as SimpleTypeReference):
		return if not LocationMatches (node)
		_nodes.Add (node)
		# Console.WriteLine ("Adding type reference {0}", node.Name)
		
	override def LeaveMemberReferenceExpression (node as MemberReferenceExpression):
		return if not LocationMatches (node)
		_nodes.Add (node)
		# Console.WriteLine ("MemberReference: {0} ({1} {2})", node, node.GetType (), node.Entity.GetType ())
		
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
		internalEntity = node as IInternalEntity
		return null if internalEntity.Node is null
		return internalEntity.Node.LexicalInfo
	if (node isa IExternalEntity):
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
	
