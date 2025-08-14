async function main() {
  // query ETH balances on Arbitrum, Base and Optimism

  const chains = [97];

  for (const chain of chains) {
    // endpoint accepts one chain at a time, loop for all your chains

    const query = await fetch(
      `https://api.etherscan.io/v2/api?module=account&chainid=97&action=balance&address=0x26C45A34dc80cc7BcfC153e27688fB1bb8213C30&apikey=TJKUQ1AFRIVXV4ZCMBEQ1G95BW9A6SMEEA`
      
    );

    const response = await query.json();

    const balance = response.result;
    console.log(balance);
  }
}

main();
