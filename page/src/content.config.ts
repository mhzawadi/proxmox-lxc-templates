import { defineCollection, z } from "astro:content";

/**
 * Templates Collection
 * Data files (YAML) containing template metadata.
 * Generated from templates config.yml files during CI build.
 */
const templates = defineCollection({
  type: "data",
  schema: z.object({
    // Basic Info
    name: z.string(),
    description: z.string(),
    category: z.string(),
    icon: z.string(),
    version: z.string(),
    build_version: z.number(),
    base_os: z.literal("debian-13"),
    architecture: z.string().default("amd64"),
    maintainer: z.string().optional(),
    project_url: z.string().url().optional(),

    // User/Group IDs (for shared volumes)
    user: z
      .object({
        uid: z.number().optional(),
        gid: z.number().optional(),
      })
      .optional(),

    // Resources
    resources: z.object({
      memory_min: z.number(),
      memory_recommended: z.number(),
      disk_min: z.string(),
      disk_recommended: z.string(),
      cores: z.number(),
    }),

    // Network
    ports: z
      .array(
        z.object({
          port: z.number(),
          description: z.string(),
        })
      )
      .optional(),

    // Filesystem
    paths: z
      .array(
        z.object({
          path: z.string(),
          description: z.string(),
        })
      )
      .optional(),

    // Authentication
    credentials: z
      .object({
        username: z.string(),
        password: z.string(),
        note: z.string().optional(),
      })
      .optional(),

    // Documentation
    quick_start: z.string().optional(),
    faq: z
      .array(
        z.object({
          question: z.string(),
          answer: z.string(),
        })
      )
      .optional(),

    // Runtime data (injected by CI)
    release_url: z.string().optional(),
    download_url: z.string().optional(),
    sha512: z.string().optional(),
    release_date: z.string().optional(),
    changelog: z.string().optional(),
  }),
});

/**
 * Docs Collection
 * Markdown files for documentation pages
 */
const docs = defineCollection({
  type: "content",
  schema: z.object({
    title: z.string(),
    description: z.string(),
    order: z.number().optional(),
    icon: z.string().optional(),
  }),
});

export const collections = {
  templates,
  docs,
};
