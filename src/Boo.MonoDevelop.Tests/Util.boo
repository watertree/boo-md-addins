namespace Boo.MonoDevelop.Tests

import MonoDevelop.Projects
import MonoDevelop.Projects.Dom.Parser

import System.IO
import Boo.Adt

let TmpDir = Path.GetTempPath()

def CreateSingleFileProject(projectName as string, code as string):
	tempFile = PathCombine(TmpDir, "Boo.MonoDevelop", projectName, projectName + ".boo")
	Directory.CreateDirectory(Path.GetDirectoryName(tempFile))
	File.WriteAllText(tempFile, code)
	project = DotNetAssemblyProject("Boo")
	project.FileName = PathCombine(TmpDir, projectName + ".booproj")
	project.AddFile(tempFile)
	return project
	
def PathCombine(*parts as (string)):
	path = parts[0]
	for part in parts[1:]:
		path = Path.Combine(path, part)
	return path
	
def GetProjectDom([required] project as Project):
	ProjectDomService.Load(project)
	dom = ProjectDomService.GetProjectDom(project)
	dom.ForceUpdate(true)
	return dom
	