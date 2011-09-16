namespace Boo.Ide

import Boo.Lang.Environments
import Boo.Lang.Compiler
import Boo.Lang.Compiler.Ast
import Boo.Lang.Compiler.TypeSystem

import Boo.Adt

let SendErrorsToTheConsole = true

class ProjectIndex:
	
	_compiler as BooCompiler
	_parser as BooCompiler
	_implicitNamespaces as List

	def constructor():
		_compiler = BooCompiler()
		_compiler.Parameters.Pipeline = Pipelines.ResolveExpressions(BreakOnErrors: false)
		
		_parser = BooCompiler()
		_parser.Parameters.Pipeline = Pipelines.Parse() { Steps.IntroduceModuleClasses() }
		_implicitNamespaces = ["Boo.Lang", "Boo.Lang.Builtins"]
	
	def constructor(compiler as BooCompiler, parser as BooCompiler, implicitNamespaces as List):
		_compiler = compiler
		_parser = parser
		_implicitNamespaces = implicitNamespaces
		
	[lock]
	virtual def Parse(fileName as string, code as string):
		return ParseModule(fileName, code)
		
	[lock]
	virtual def ProposalsFor(fileName as string, code as string):
		result = {}
		
		WithModule(fileName, code) do (module):
			expression = CursorLocationFinder().FindIn(module)
			if not expression is null:
				for proposal in CompletionProposer.ForExpression(expression):
					result[proposal.Name] = proposal
						
		return array(CompletionProposal, result.Values)
		
	[lock]
	virtual def MethodsFor(fileName as string, code as string, methodName as string, methodLine as int):
		methods = List of MethodDescriptor()
		
		WithModule(fileName, code) do (module):
			expression = MethodInvocationFinder(methodName, fileName, methodLine).FindIn(module)
			if expression is null:
				print "No method found for ${methodName}: (${fileName}:${methodLine})"
				return
			if expression.Target.Entity isa Ambiguous:
				# Multiple overloads
				for i in (expression.Target.Entity as Ambiguous).Entities:
					methods.Add (MethodDescriptor(i))
			elif expression.Target.Entity isa IMethod:
				# May have failed resolution - try one more time
				entity = Services.NameResolutionService().ResolveMethod((expression.Target.Entity as IMethod).DeclaringType, methodName)
				if entity isa Ambiguous:
					# Multiple overloads
					for i in (expression.Target.Entity as Ambiguous).Entities:
						methods.Add (MethodDescriptor(i))
				else:
					# No overloads
					methods.Add(MethodDescriptor(entity))
		return methods
		
	[lock]
	virtual def LocalsAt(fileName as string, code as string, line as int):
		locals = List of string()
		WithModule(fileName, code) do (module):
			locals.Extend(LocalAccumulator(fileName, line).FindIn(module))
		return locals
		
	[lock]
	virtual def ImportsFor(fileName as string, code as string):
		module = ParseModule(fileName, code)
		imports = List of string(i.Namespace for i in module.Imports)
		imports.Extend(_implicitNamespaces)
		return imports
		
	[lock]
	virtual def AddReference(assembly as System.Reflection.Assembly):
		_compiler.Parameters.References.Add(assembly)
		
	[lock]
	virtual def AddReference(reference as string):
		asm = _compiler.Parameters.LoadAssembly(reference, true)
		_compiler.Parameters.References.Add(asm)
		
	[lock]
	virtual def TargetOf (fileName as string, code as string, line as int, column as int) as TokenLocation:
		result = null as TokenLocation
		
		WithModule(fileName, code) do (module):
			result = TargetLookup (fileName, line, column).FindIn (module)
		return result
		
	private def WithModule(fname as string, contents as string, action as System.Action[of Module]):
		input = _compiler.Parameters.Input
		input.Add(IO.StringInput(fname, contents))
		try:
			context = _compiler.Run()
			ActiveEnvironment.With(context.Environment) do:
				action(GetModuleForFileFromContext(context, fname))
		ensure:
			input.Clear()
		
	private def GetModuleForFileFromContext(context as CompilerContext, fileName as string):
		for m in context.CompileUnit.Modules:
			if m.LexicalInfo.FileName == fileName:
				return m
		return null
		
	private def ParseModule(fileName as string, contents as string):
		try:
			_parser.Parameters.Input.Add(IO.StringInput(fileName, contents))
			result = _parser.Run()
			DumpErrors result.Errors
			return result.CompileUnit.Modules[-1]
		except x:
			print x
			return Module(LexicalInfo(fileName, 1, 1))
		ensure:
			_parser.Parameters.Input.Clear()
				
def DumpErrors(errors as CompilerErrorCollection):
	if SendErrorsToTheConsole:
		for error in errors:
			System.Console.Error.WriteLine(error.ToString(true))

