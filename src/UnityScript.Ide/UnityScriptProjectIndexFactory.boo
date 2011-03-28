namespace UnityScript.Ide

import Boo.Ide
import Boo.Lang.Compiler
import UnityScript

static class UnityScriptProjectIndexFactory:
	
	final ScriptMainMethod = "Main"
	final ImplicitImports = List[of string]() { "UnityEngine", "UnityEditor", "System.Collections" }
	
	def CreateUnityScriptProjectIndex() as ProjectIndex:
		return ProjectIndex(CreateCompiler(), CreateParser(), [])
		
	private def CreateCompiler():
		pipeline = UnityScriptCompiler.Pipelines.AdjustBooPipeline(Boo.Lang.Compiler.Pipelines.ResolveExpressions())
		pipeline.InsertAfter(UnityScript.Steps.Parse, ResolveMonoBehaviourType())
		pipeline.BreakOnErrors = false
		return CompilerWithPipeline(pipeline)
		
	private def CreateParser():
		pipeline = UnityScriptCompiler.Pipelines.Parse()
		pipeline.InsertAfter(UnityScript.Steps.Parse, ResolveMonoBehaviourType())
		pipeline.BreakOnErrors = false
		return CompilerWithPipeline(pipeline)
		
	private def CompilerWithPipeline(pipeline):
		parameters = UnityScriptCompilerParameters(ScriptMainMethod: ScriptMainMethod, Pipeline: pipeline)
		parameters.Imports = ImplicitImports
		return BooCompiler(parameters)

