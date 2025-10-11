type Region = {
  id: number;
  code: string;
  name: string;
  level: number;            // 1 = province, 2 = regency/city, dll
  type: "province" | "regency" | "city" | "district" | "village" | "urban village";
  parent_code: string | null;
};

const api = (level: number) =>
  `https://raw.githubusercontent.com/reimiii/kdwa-indonesia/refs/heads/main/json/${level}.json`;

async function getProvinces(url: string): Promise<Region[]> {
  const res = await fetch(url);
  const data: Region[] = await res.json() as Region[];
  return data;
}

async function getRegencies(url: string) {
  const res = await fetch(url);
  const data = await res.json() as Region[];
  const result = data.filter((d) => d.type === 'regency')
  return result;
}

async function getCities(url: string) {
  const res = await fetch(url);
  const data = await res.json() as Region[];
  const result = data.filter((d) => d.type === 'city')
  return result;
}

async function getDistricts(url: string) {
  const res = await fetch(url);
  const data = await res.json() as Region[];
  const result = data.filter((d) => d.type === 'district')
  return result;
}

async function getUrbanVillages(url: string) {
  const res = await fetch(url);
  const data = await res.json() as Region[];
  const result = data.filter((d) => d.type === 'urban village')
  return result;
}

async function getVillages(url: string) {
  const res = await fetch(url);
  const data = await res.json() as Region[];
  const result = data.filter((d) => d.type === 'village')
  return result;
}

async function main() {
  const provinces = await getProvinces(api(1));
  console.log(`province: ${provinces.length}`)

  const cities = await getCities(api(2));
  console.log(`cities: ${cities.length}`)

  const regencies = await getRegencies(api(2));
  console.log(`regency: ${regencies.length}`)

  const districts = await getDistricts(api(3));
  console.log(`district: ${districts.length}`)

  const urbans = await getUrbanVillages(api(4));
  console.log(`urban: ${urbans.length}`)

  const villages = await getVillages(api(4));
  console.log(`village: ${villages.length}`)
}

await main();
