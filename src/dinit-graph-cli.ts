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

interface DinitProperty {
	propertyName: string,
	serviceName: string,
}

let ServiceDirProperties = new Map<string, DinitProperty[]>();

function validateArgs(args: { serviceDirectory: string }): string {
	const targetDirFile = (Bun.file(args.serviceDirectory ?? ""))?.name ?? "";
	const bootServiceFile = (Bun.file(targetDirFile + "/boot"))?.name ?? "";
	const targetDirStats = fs.statSync(targetDirFile ?? "");
	const bootServiceStats = fs.statSync(bootServiceFile ?? "");

	// Validate the inputs
	if (!targetDirStats || !targetDirStats.isDirectory) {
		throw new Error("Service directory is not valid or doesn't exist.");
	}
	if (!bootServiceStats || bootServiceStats.size == 0) {
		throw new Error("A valid boot service file was not found.");
	}

	return targetDirFile;
}

/**
 * Parses the Dinit properties for dependency ordering
 * @param serviceFile Dinit service file as BunFile
 */
function parseProperties(serviceFile: string): DinitProperty[] {
	const serviceContent = fs.readFileSync(serviceFile ?? "",
		{
			encoding: "utf-8",
			flag: "r",
		});

	const propRegex = /^(depends-on|depends-ms|waits-for|after)\s*[:=]\s*(.+)$/gm;
	const propArray: DinitProperty[] = [];
	let line: string;
	let match;

	for (line of serviceContent.split('\n')) {
		line = line.trim();
		if (line.startsWith('#')) continue;

		match = propRegex.exec(line);
		if (match) {
			propArray.push({
				propertyName: match[1] ?? "",
				serviceName: match[2] ?? ""
			});
		}
	}

	return propArray;
}

/**
 * parses dinit properties from all service files in a directory, returns ServiceInfo
 * 
 */
function parsePropertiesDirectory(targetDirectoryFile: string): Map<string, DinitProperty[]> {
	const properties = new Map<string, DinitProperty[]>();

	fs.readdirSync(targetDirectoryFile ?? "",
		{
			withFileTypes: true,
			recursive: true,
		})
		.filter(file => {
			return !file.isDirectory;
		})
		.forEach(file => {
			properties.set(file.name ?? "", parseProperties(file.parentPath + file.name));
		});

	return properties;
}

/**
 * adds the dependencies to the dag for one particular service file
 * @param dag 
 * @param serviceFile 
 */
function addDependencyPropsRecursively(dag: DirectedAcyclicGraph, srv: string) {
	if (!dag || !srv) {
		throw ReferenceError("objects passed to method are null");
	}

	const properties = ServiceDirProperties.get(srv);
	if (properties != null && properties != undefined) {
		for (let prop of properties) {
			if (!dag.hasVertex(prop.serviceName)) {
				dag.addVertex(prop.serviceName);
				addDependencyPropsRecursively(dag, prop.serviceName);
			}
			if (dag.hasVertex(prop.serviceName) && !dag.hasEdge(srv, prop.serviceName)) {
				dag.addEdge(srv, prop.serviceName);
			}
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
		ServiceDirProperties = parsePropertiesDirectory(targetDirectory);
		const bootServiceFile = (Bun.file(targetDirectory + "/boot"))?.name ?? "";
		const orderedGraph = new DirectedAcyclicGraph(bootServiceFile);
		addDependencyPropsRecursively(orderedGraph, bootServiceFile);

		const sorted = orderedGraph.topologicalSort();
		console.log(sorted);

	});

await cli.execute();