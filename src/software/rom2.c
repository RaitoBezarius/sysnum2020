void _start() {
    unsigned int epoch = 0;

    unsigned int seconds = 0,
                 minutes = 0,
                 hours = 0,
                 days = 0,
                 months = 0,
                 years = 0;
    
    while(1) {
        epoch++;

        seconds = epoch % 60;
        minutes = (int)(epoch / 60) % 60;
        hours = (int)(epoch / (60*60)) % 24;
        days = (int)(epoch / (60*60*24)) % 31;
        months = (int)(epoch / (60*60*24*31)) % 12;
        years = (int)(epoch / (60*60*24*31*12));
    }
}
