#! /usr/bin/env bun
/**
 * dinit-graph
 * by: Andrew Velez
 */
import * as fs from "node:fs";
import * as path from "node:path";
import { Crust } from "@crustjs/core";
import { helpPlugin, versionPlugin } from "@crustjs/plugins";
import pkg from "../package.json" assert { type: "json" };
import { DirectedAcyclicGraph } from "./DirectedAcyclicGraph";

interface DinitProperty {
	propertyName: string,
	serviceName: string,
}

let targetDirectory: string;

function validateArgs(args: { serviceDirectory: string }): string {
	targetDirectory = path.resolve(args.serviceDirectory ?? "");
	const bootService = path.join(targetDirectory, "boot");

	if (!fs.existsSync(targetDirectory) || !fs.statSync(targetDirectory).isDirectory()) {
		throw new Error(`Service directory is not valid or doesn't exist: ${targetDirectory}`);
	}
	if (!fs.existsSync(bootService)) {
		throw new Error("A valid 'boot' service file was not found in the directory.");
	}

	return targetDirectory;
}

/**
 * Parses the Dinit properties for dependency ordering
 * @param serviceFile Dinit service file as BunFile
 */
function parseProperties(serviceFile: string): DinitProperty[] {
	const serviceContent = fs.readFileSync(serviceFile, { encoding: "utf-8" });

	const propRegex = /^(depends-on|depends-ms|waits-for|after)(.d)*\s*[:=]\s*(.+)$/;
	const propArray: DinitProperty[] = [];

	let index: number;
	let split: string[];
	let match;
	let dirServices: string;
	let subdirFiles: fs.Dirent<string>[];
	for (let line of serviceContent.split('\n')) {

		line = line.trim();
		match = line.match(propRegex);

		if (match) {
			if (!line || line.startsWith('#')) {
				continue;
			}
			index = line.indexOf('#');
			if (index > 0) {
				line = line.substring(0, index);
			}

			split = line.split(/[:=]/);
			if (split.length < 2) {
				continue;
			}
			if (split[0]?.trim().endsWith(".d")) {
				dirServices = path.join(targetDirectory, split[1]?.trim() ?? "");

				if (fs.existsSync(dirServices)) {
					subdirFiles = fs.readdirSync(dirServices, { withFileTypes: true });
					if (subdirFiles && subdirFiles.length > 0) {
						for (let subdirfile of subdirFiles) {
							if (subdirfile && !subdirfile.isDirectory()) {
								propArray.push({
									propertyName: split[0]?.trim() ?? "",
									serviceName: path.join(dirServices, subdirfile.name),
								});
							}
						}
					}
				}

			}
			else {
				propArray.push({
					propertyName: split[0]?.trim() ?? "",
					serviceName: split[1]?.trim() ?? "",
				})
			}
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
	const entries = fs.readdirSync(targetDirectoryFile, { withFileTypes: true });

	for (const entry of entries) {
		const fullPath = path.join(targetDirectoryFile, entry.name);

		if (entry.isDirectory()) {

			const subFiles = fs.readdirSync(fullPath, { withFileTypes: true })
				.filter(f => f.isFile());

			const dirContents: DinitProperty[] = subFiles.map(f => ({
				propertyName: "directory-link",
				serviceName: f.name
			}));

			properties.set(entry.name, dirContents);

			for (const f of subFiles) {
				const subFilePath = path.join(fullPath, f.name);
				properties.set(f.name, parseProperties(subFilePath));
			}
		} else {
			properties.set(entry.name, parseProperties(fullPath));
		}
	}

	return properties;
}

/**
 * adds the dependencies to the dag for one particular service file
 * @param dag 
 * @param serviceFile 
 */
function addDependencyPropsRecursively(dag: DirectedAcyclicGraph<string>, allServiceProps: Map<string, DinitProperty[]>,
	srv: string) {

	if (!dag || !allServiceProps || !srv) {
		throw new ReferenceError("objects passed to method are null");
	}

	const properties = allServiceProps.get(srv);
	if (properties != null) {
		for (let prop of properties) {
			const depName = prop.serviceName;
			const isNew = !dag.hasVertex(depName);

			// Add the dependency edge
			dag.addEdge(srv, depName);

			// Only recurse if we haven't explored this service's dependencies yet
			if (isNew) {
				addDependencyPropsRecursively(dag, allServiceProps, depName);
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

		targetDirectory = validateArgs(args);
		const targetDirServiceProperties = parsePropertiesDirectory(targetDirectory);

		const orderedGraph = new DirectedAcyclicGraph<string>("boot");
		addDependencyPropsRecursively(orderedGraph, targetDirServiceProperties, "boot");

		const sorted = orderedGraph.topologicalSort();
		console.log(sorted.reverse());

	});

await cli.execute();