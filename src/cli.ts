#! /usr/bin/env bun
/**
 * dinit-graph
 * by: Andrew Velez
 */
import * as fs from "node:fs";
import { Crust } from "@crustjs/core";
import { helpPlugin, versionPlugin } from "@crustjs/plugins";
import pkg from "../package.json" assert { type: "json" };

interface ServiceBody {
	parsed: boolean;
}

type DinitProperty = {
	propertyName: string,
	namedService: string
}

/**
 * Parses the Dinit properties for dependency ordering
 * @param serviceFile Dinit service file as BunFile
 */
function parseServiceFile(serviceFilePath: string): DinitProperty[] {
	const serviceContent = fs.readFileSync(serviceFilePath ?? "",
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
		},
	])
	.run(({ args }) => {
		const targetDirFile = Bun.pathToFileURL(args.serviceDirectory ?? "");
		const bootServiceFile = Bun.pathToFileURL(targetDirFile + "/boot");
		const targetDirectory = fs.statSync(targetDirFile);
		const bootService = fs.statSync(bootServiceFile);

		if (!targetDirectory || !targetDirectory.isDirectory) {
			console.error("Service directory is not valid or doesn't exist.");
			process.exit(1);
		}
		if (!bootService || bootService.size == 0) {
			console.error("A valid boot service file was not found.");
			process.exit(1);
		}

		// Parse through all the service files once putting the relevant ordering
		// properties into a more convenient array.
		let allServicesProperties = [];
		const files = fs.readdirSync(targetDirFile,
			{
				withFileTypes: true,
				recursive: true,
			})
			.filter(file => {
				return !file.isDirectory;
			})
			.forEach(file => {
				allServicesProperties.push({
					serviceFile: Bun.pathToFileURL(file.parentPath + file.name),
					serviceProperties: parseServiceFile(file.parentPath + file.name),
				})
			});

	});

await cli.execute();