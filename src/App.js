import './App.css';
import { useState }  from 'react';
import axios from 'axios';

function App() {
const [Name, setName] = useState('')
const [CreditCard, setCreditCard] = useState('')
console.log(process.env.REACT_APP_BACKEND_URL)

const getDetails = () => {
     axios.get(process.env.REACT_APP_BACKEND_URL)
     .then(res => {
      console.log(res.data)
      setCreditCard(res.data.CreditCard)

     }).catch(err => {
      console.log('We will be with you shortly')
     })
}

  return (
    <div className="App"> 
    <button onClick={getDetails}>Click HERE to Submit Task</button>
    <p>{Name}</p>
    
    <p>{CreditCard}</p>

    </div>
  );
}

export default App;
