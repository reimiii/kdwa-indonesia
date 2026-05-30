import { cwd } from "node:process";

const SCRIPTS = [
  { name: "import_raw.sh", desc: "Download & import raw wilayah data" },
  { name: "migrate_regions.sh", desc: "Transform raw data into regions table" },
];

export default async function run() {
  console.log("Running update command...\n");

  for (const { name, desc } of SCRIPTS) {
    const script = `${cwd()}/scripts/${name}`;
    console.log(`[${desc}]`);

    const proc = Bun.spawn(["bash", script], {
      stdout: "inherit",
      stderr: "inherit",
    });

    const exitCode = await proc.exited;

    if (exitCode !== 0) {
      console.error(`\nFailed: ${name} (exit ${exitCode})`);
      process.exit(exitCode);
    }

    console.log("");
  }

  console.log("Update complete. Database is in sync!");
}