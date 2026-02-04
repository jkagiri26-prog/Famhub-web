// Main JavaScript app file for FamHub
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';

// Initialize Supabase client
const supabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// App initialization
document.addEventListener('DOMContentLoaded', function() {
    console.log('FamHub app initialized with Supabase');

    // Check if user is logged in
    const checkUser = async () => {
        const { data: { user } } = await supabase.auth.getUser();
        if (user) {
            console.log('User is logged in:', user.email);
            // Show dashboard or redirect to main app
            showDashboard(user);
        } else {
            console.log('No user logged in');
            // Show login/signup options
            showLoginOptions();
        }
    };

    // Show login/signup options
    const showLoginOptions = () => {
        // This would integrate with your existing HTML modal
        console.log('Showing login options');
    };

    // Show dashboard for logged in user
    const showDashboard = (user) => {
        console.log('Showing dashboard for:', user.email);
        // This would show the main app interface
    };

    // Initialize the app
    checkUser();
});