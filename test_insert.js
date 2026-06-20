import { createClient } from '@supabase/supabase-js'

const supabase = createClient(process.env.VITE_SUPABASE_URL, process.env.VITE_SUPABASE_ANON_KEY)

async function test() {
  console.log("Checking Supabase connection...")
  const { data, error } = await supabase.from('businesses').insert([{
    business_type: 'Test',
    business_name: 'Test Name'
  }])
  console.log("Insert result:", { data, error })
}

test()
