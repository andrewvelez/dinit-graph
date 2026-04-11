/**
 * dinit-graph
 * by: Andrew Velez
 */
import { Crust } from "@crustjs/core";
import { helpPlugin, versionPlugin } from "@crustjs/plugins";
import { DiGraph } from "digraph-js";
import pkg from "../package.json";

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
			description: "directory of Dinit service files",
		},
	])
	.run(({ args }) => {

		// valid service directory

		// build digraph

	});

await cli.execute();
