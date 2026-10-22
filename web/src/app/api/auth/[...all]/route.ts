import { toNextJsHandler } from "better-auth/next-js";
import { getAuth } from "@/server/runtime";

export const { GET, POST, PATCH, PUT, DELETE } = toNextJsHandler(async (request) =>
  (await getAuth()).handler(request),
);
