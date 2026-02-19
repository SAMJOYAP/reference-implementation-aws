export const projectName = "${{ values.name }}";

export function appInfo(): string {
  return `Project ${projectName} uses TypeScript scaffolding.`;
}
