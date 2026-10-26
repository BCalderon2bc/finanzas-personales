import 'package:flutter/material.dart';
import '../../data/card_statement_logic.dart';

class CreditCardStatementForm extends StatefulWidget {
  const CreditCardStatementForm({super.key,this.statement});
  final Map<String,dynamic>? statement;
  @override
  State<CreditCardStatementForm> createState()=>_CreditCardStatementFormState();
}
class _CreditCardStatementFormState extends State<CreditCardStatementForm> {
  final formKey=GlobalKey<FormState>();
  final balance=TextEditingController(),minimum=TextEditingController(),notes=TextEditingController();
  String currency='NIO';
  DateTime closing=DateTime.now(),due=DateTime.now().add(const Duration(days:20));
  bool get editing=>widget.statement != null;
  @override
  void initState() {
    super.initState();final s=widget.statement;
    if(s != null) {
      currency='${s['currency']}';balance.text='${s['balance_due']}';
      minimum.text=s['minimum_due']?.toString() ?? '';notes.text=s['notes']?.toString() ?? '';
      closing=statementDate(s['closing_date'])!;due=statementDate(s['due_date'])!;
    }
  }
  @override
  void dispose(){balance.dispose();minimum.dispose();notes.dispose();super.dispose();}
  String? validateAmount(String? value,{bool optional=false}) {
    final text=(value??'').trim();if(optional && text.isEmpty){return null;}
    final n=double.tryParse(text.replaceAll(',','.'));
    if(!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)||n==null||!n.isFinite||n<0||n>999999999999.99){
      return 'Monto no negativo, máximo dos decimales y sin separadores de miles.';
    }
    return null;
  }
  String dateValue(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  void save() {
    if(!formKey.currentState!.validate()){return;}
    if(daysUntil(due,closing)<0){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('El vencimiento no puede ser anterior al corte.')));return;
    }
    Navigator.pop(context,<String,dynamic>{
      'currency':currency,'closing_date':dateValue(closing),'due_date':dateValue(due),
      'balance':double.parse(balance.text.trim().replaceAll(',','.')),
      'minimum':minimum.text.trim().isEmpty?null:double.parse(minimum.text.trim().replaceAll(',','.')),
      'notes':notes.text.trim(),
    });
  }
  @override
  Widget build(BuildContext context)=>AlertDialog(
    title:Text(editing?'Editar corte registrado':'Registrar estado de cuenta'),
    content:SizedBox(width:460,child:SingleChildScrollView(child:Form(key:formKey,
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Text('Copia estos datos del estado de cuenta del banco. Son informativos: registrar un corte no agrega deuda ni descuenta dinero.'),
        const SizedBox(height:16),
        DropdownButtonFormField<String>(initialValue:currency,
          decoration:const InputDecoration(labelText:'Moneda del estado de cuenta'),
          items:const[DropdownMenuItem(value:'NIO',child:Text('Córdobas · C\$')),
            DropdownMenuItem(value:'USD',child:Text('Dólares · US\$'))],
          onChanged:editing?null:(v){if(v!=null){setState(()=>currency=v);}}),
        const SizedBox(height:12),
        TextFormField(controller:balance,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:InputDecoration(labelText:'Saldo al corte · $currency'),validator:(v)=>validateAmount(v)),
        const SizedBox(height:12),
        TextFormField(controller:minimum,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:const InputDecoration(labelText:'Pago mínimo (opcional)',helperText:'Déjalo vacío si no lo conoces; no equivale a cero.',helperMaxLines:2),
          validator:(v){
            final invalid=validateAmount(v,optional:true);if(invalid!=null){return invalid;}
            final m=double.tryParse((v??'').trim().replaceAll(',','.'));
            final b=double.tryParse(balance.text.trim().replaceAll(',','.'));
            return m!=null && b!=null && m>b?'El mínimo no puede superar el saldo al corte.':null;
          }),
        const SizedBox(height:12),
        OutlinedButton.icon(icon:const Icon(Icons.event_outlined),
          label:Text('Corte: ${shortStatementDate(dateValue(closing))}'),onPressed:()async{
            final d=await showDatePicker(context:context,initialDate:closing,firstDate:DateTime(2000),lastDate:DateTime(2100));
            if(d!=null && mounted){setState(()=>closing=d);}
          }),
        OutlinedButton.icon(icon:const Icon(Icons.event_available_outlined),
          label:Text('Vencimiento: ${shortStatementDate(dateValue(due))}'),onPressed:()async{
            final d=await showDatePicker(context:context,initialDate:due,firstDate:DateTime(2000),lastDate:DateTime(2100));
            if(d!=null && mounted){setState(()=>due=d);}
          }),
        const SizedBox(height:12),TextFormField(controller:notes,maxLines:2,decoration:const InputDecoration(labelText:'Notas (opcional)')),
        if(!editing) const Padding(padding:EdgeInsets.only(top:12),child:Text(
          'Un nuevo corte reemplaza al vigente de esa moneda y conserva el anterior en el historial. '
          'Registra el saldo completo que informa el banco, aunque incluya montos de períodos anteriores.',
          style:TextStyle(fontSize:12,color:Color(0xFF64748B)))),
      ])))),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancelar')),
      FilledButton(onPressed:save,child:const Text('Guardar corte'))]);
}
