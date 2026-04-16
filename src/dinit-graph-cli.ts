#! /usr/bin/env bun
/**
 * dinit-graph
 * by: Andrew Velez
 */
import * as fs from "node:fs";
import { Crust } from "@crustjs/core";
import { helpPlugin, versionPlugin } from "@crustjs/plugins";
import pkg from "../package.json" assert { type: "json" };
import { DirectedAcyclicGraph } from "./DirectedAcyclicGraph";
import { ServiceDependencyGraph } from "./ServiceDependencyGraph";

interface DinitProperty {
	propertyName: string,
	namedService: string,
}

interface ServiceInfo {
	serviceFile: string,
	serviceProperties: DinitProperty[],
}

function validateArgs(args): string {
	const targetDirFile = Bun.file(args.serviceDirectory ?? "");
	const bootServiceFile = Bun.file(targetDirFile + "/boot");
	const targetDirStats = fs.statSync(targetDirFile.name ?? "");
	const bootServiceStats = fs.statSync(bootServiceFile.name ?? "");

	// Validate the inputs
	if (!targetDirStats || !targetDirStats.isDirectory) {
		throw new Error("Service directory is not valid or doesn't exist.");
	}
	if (!bootServiceStats || bootServiceStats.size == 0) {
		throw new Error("A valid boot service file was not found.");
	}

	return targetDirFile?.name ?? "";
}

/**
 * Parses the Dinit properties for dependency ordering
 * @param serviceFile Dinit service file as BunFile
 */
function parseFileDinitProperties(serviceFile: string): DinitProperty[] {
	const serviceContent = fs.readFileSync(serviceFile ?? "",
		{
			encoding: "utf-8",
			flag: "r",
		});

	const propRegex = /^(depends-on|depends-ms|waits-for|after)\s*[:=]\s*(.+)$/gm;
	const propArray: DinitProperty[] = [];
	let line, match;

	for (line of serviceContent.split('\n')) {
		line = line.trim();
		if (line.startsWith('#')) continue;

		match = propRegex.exec(line);
		if (match) {
			propArray.push({
				propertyName: match[1] ?? "",
				namedService: match[2] ?? ""
			});
		}
	}

	return propArray;
}

/**
 * parses dinit properties from all service files in a directory, returns ServiceInfo
 * 
 */
function parseDirectoryDinitProperties(targetDirectoryFile: string): Map<string, ServiceInfo> {
	let parsedServicesAndProperties: Map<string, ServiceInfo> = new Map<string, ServiceInfo>();
	const files = fs.readdirSync(targetDirectoryFile ?? "",
		{
			withFileTypes: true,
			recursive: true,
		})
		.filter(file => {
			return !file.isDirectory;
		})
		.forEach(file => {
			parsedServicesAndProperties.set(file.name ?? "",
				{
					serviceFile: Bun.file(file.parentPath + file.name).name ?? "",
					serviceProperties: parseFileDinitProperties(file.parentPath + file.name),
				});
		});

	return parsedServicesAndProperties;
}

/**
 * adds the dependencies to the dag for one particular service file
 * @param dag 
 * @param serviceFile 
 */
function addServiceDependencies(dag: DirectedAcyclicGraph, sourceService: ServiceInfo) {
	if (!dag || !sourceService) {
		throw ReferenceError("objects passed to method are null");
	}

	for (let itrProperty of sourceService.serviceProperties) {
		if (!dag.hasVertex(itrProperty.namedService)) {
			dag.addVertex(itrProperty.namedService);
			addServiceDependencies(dag, itrProperty.namedService);
		}
		if (dag.hasVertex(itrProperty.namedService) && !dag.hasEdge(sourceService.serviceFile, itrProperty.namedService)) {
			dag.addEdge(sourceService.serviceFile, itrProperty.namedService);
		}
	}
}

const cli = new Crust("dinit-graph")
	.meta({
		description: "Builds a dependency graph based on Dinit service files",
		usage: "dinit-graph <services-directory>",
	})
	.use(versionPlugin(pkg.version))
	.use(helpPlugin())
	.args([
		{
			name: "serviceDirectory",
			type: "string",
			description: "absolute directory of Dinit service files",
			required: true,
		},
	])
	.run(({ args }) => {
		const targetDirectory = validateArgs(args);

		// First parse to extract all the Dinit properties from all files
		const parsedServicesAndProperties = parseDirectoryDinitProperties(targetDirectory);

		// Construct DAG starting at the boot service
		const bootService = Bun.file(targetDirectory + "/boot");
		const orderedGraph = new DirectedAcyclicGraph(bootService);

		const test = new DirectedAcyclicGraph<string>(bootService?.name ?? "");
		const test = new 

	});

await cli.execute();