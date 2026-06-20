import { createClient } from '@supabase/supabase-js'

const supabase = createClient(process.env.VITE_SUPABASE_URL, process.env.VITE_SUPABASE_ANON_KEY)

async function test() {
  console.log("Checking Supabase connection...")
  const { data, error, count } = await supabase.from('businesses').select('*', { count: 'exact', head: true })
  if (error) {
    console.error("Error connecting or querying:", error)
  } else {
    console.log("Success! Count of businesses:", count)
  }
}

test()
