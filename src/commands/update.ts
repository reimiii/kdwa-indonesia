import { cwd } from "node:process";

export default async function run() {
  console.log("Running update command...");

  const scripts = [
    `${cwd()}/scripts/import_raw.sh`,
    `${cwd()}/scripts/migrate_regions.sh`,
  ];

  for (const script of scripts) {
    console.log(`Executing ${script} ...`);

    const proc = Bun.spawn(["bash", script], {
      stdout: "inherit",
      stderr: "inherit",
    });

    const exitCode = await proc.exited;

    if (exitCode !== 0) {
      console.error(`Script failed: ${script} (exit ${exitCode})`);
      process.exit(exitCode);
    }
  }

  console.log("Update complete. Database is now in sync!");
}