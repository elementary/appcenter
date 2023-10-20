void main (string[] args) {
    Test.init (ref args);
    add_card_tests ();
    add_houston_tests ();
    add_soup_client_tests ();
    add_stripe_tests ();
    Test.run ();
}
