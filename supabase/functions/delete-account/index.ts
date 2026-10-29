import { createDeletionHandler } from "./handler.ts";
import { deletionDependencies } from "./dependencies.ts";

Deno.serve(createDeletionHandler(deletionDependencies()));
