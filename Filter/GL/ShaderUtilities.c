
//	Copyright 2015 Michel Fortin
//
//	Licensed under the Apache License, Version 2.0 (the "License");
//	you may not use this file except in compliance with the License.
//	You may obtain a copy of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
//	Unless required by applicable law or agreed to in writing, software
//	distributed under the License is distributed on an "AS IS" BASIS,
//	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//	See the License for the specific language governing permissions and
//	limitations under the License.

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include "ShaderUtilities.h"

#define LogInfo printf
#define LogError printf

/* Compile a shader from the provided source(s) */
GLint glueCompileShader(GLenum target, GLsizei count, const GLchar **sources, GLuint *shader)
{
	GLint status;
    
	*shader = glCreateShader(target);	
	glShaderSource(*shader, count, sources, NULL);
	glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength = 0;
	glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0)
	{
		GLchar *log = (GLchar *)malloc(logLength);
		glGetShaderInfoLog(*shader, logLength, &logLength, log);
		LogInfo("Shader compile log:\n%s", log);
		free(log);
	}
#endif
    
	glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
	if (status == 0)
	{
		int i;
		
		LogError("Failed to compile shader:\n");
		for (i = 0; i < count; i++)
			LogInfo("%s", sources[i]);	
	}
	
	return status;
}


/* Link a program with all currently attached shaders */
GLint glueLinkProgram(GLuint program)
{
	GLint status;
	
	glLinkProgram(program);
	
#if defined(DEBUG)
    GLint logLength = 0;
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0)
	{
		GLchar *log = (GLchar *)malloc(logLength);
		glGetProgramInfoLog(program, logLength, &logLength, log);
		LogInfo("Program link log:\n%s", log);
		free(log);
	}
#endif
    
	glGetProgramiv(program, GL_LINK_STATUS, &status);
	if (status == 0)
		LogError("Failed to link program %d", program);
	
	return status;
}


/* Validate a program (for i.e. inconsistent samplers) */
GLint glueValidateProgram(GLuint program)
{
	GLint status;
	
	glValidateProgram(program);
    
#if defined(DEBUG)
    GLint logLength = 0;
	glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0)
	{
		GLchar *log = (GLchar *)malloc(logLength);
		glGetProgramInfoLog(program, logLength, &logLength, log);
		LogInfo("Program validate log:\n%s", log);
		free(log);
	}
#endif
    
	glGetProgramiv(program, GL_VALIDATE_STATUS, &status);
	if (status == 0)
		LogError("Failed to validate program %d", program);
	
	return status;
}


/* Return named uniform location after linking */
GLint glueGetUniformLocation(GLuint program, const GLchar *uniformName)
{
    GLint loc;
    
    loc = glGetUniformLocation(program, uniformName);
    
    return loc;
}


/* Convenience wrapper that compiles, links, enumerates uniforms and attribs */
GLint glueCreateProgram(const GLchar *vertSource, const GLchar *fragSource,
                        GLsizei attribNameCt, const GLchar **attribNames, 
                        const GLint *attribLocations,
                        GLsizei uniformNameCt, const GLchar **uniformNames, 
                        GLint *uniformLocations,
                        GLuint *program)
{
	GLuint vertShader = 0, fragShader = 0, prog = 0, status = 1, i;
	
    // Create shader program
	prog = glCreateProgram();
    
    // Create and compile vertex shader
	status *= glueCompileShader(GL_VERTEX_SHADER, 1, &vertSource, &vertShader);
    
    // Create and compile fragment shader
	status *= glueCompileShader(GL_FRAGMENT_SHADER, 1, &fragSource, &fragShader);
    
    // Attach vertex shader to program
	glAttachShader(prog, vertShader);
    
    // Attach fragment shader to program
	glAttachShader(prog, fragShader);
	
    // Bind attribute locations
    // This needs to be done prior to linking
	for (i = 0; i < attribNameCt; i++)
	{
		if(strlen(attribNames[i]))
			glBindAttribLocation(prog, attribLocations[i], attribNames[i]);
	}
	
    // Link program
	status *= glueLinkProgram(prog);
    
    // Get locations of uniforms
	if (status)
	{	
        for(i = 0; i < uniformNameCt; i++)
		{
            if(strlen(uniformNames[i]))
			    uniformLocations[i] = glueGetUniformLocation(prog, uniformNames[i]);
		}
		*program = prog;
	}
    
    // Release vertex and fragment shaders
	if (vertShader)
		glDeleteShader(vertShader);
	if (fragShader)
		glDeleteShader(fragShader);
    
	return status;
}
