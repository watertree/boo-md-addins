namespace Boo.MonoDevelop.Util

import MonoDevelop.Projects
import Boo.Ide
import UnityScript.Ide
	
static class ProjectIndexFactory:
	indices = System.Collections.Generic.Dictionary[of DotNetProject,ProjectIndex]()
	
	def ForProject(project as DotNetProject):
		if project is null:
			return ProjectIndex()
		if indices.ContainsKey(project):
			return indices[project]
		
		index = CreateIndexFor(project)
		indices[project] = index
		return index
		
	private def CreateIndexFor(project as DotNetProject):
		booLanguageBinding = project.LanguageBinding as IBooIdeLanguageBinding 
		if booLanguageBinding is not null:
			return booLanguageBinding.ProjectIndexFor(project)
		return MixedProjectIndex(project, ProjectIndex(), UnityScriptProjectIndexFactory.CreateUnityScriptProjectIndex())
			
def LogError(x):
	System.Console.Error.WriteLine(x)
	