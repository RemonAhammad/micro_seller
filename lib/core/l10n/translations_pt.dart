const translationsPt = <String, String>{
  // Navigation
  'dashboard': 'Painel',
  'products': 'Produtos',
  'orders': 'Pedidos',
  'customers': 'Clientes',
  'inventory': 'Estoque',
  'expenses': 'Despesas',
  'categories': 'Categorias',
  'settings': 'Configurações',
  'reports': 'Relatórios',

  // Dashboard
  'todayRevenue': 'Receita de hoje',
  'monthRevenue': 'Receita do mês',
  'monthProfit': 'Lucro do mês',
  'totalOrders': 'Total de pedidos',
  'pendingOrders': 'Pedidos pendentes',
  'unpaidAmount': 'Valor não pago',
  'lowStockItems': 'Itens com estoque baixo',
  'weeklySales': 'Vendas semanais',
  'goodMorning': 'Bom dia',
  'goodAfternoon': 'Boa tarde',
  'goodEvening': 'Boa noite',

  // Products
  'addProduct': 'Adicionar produto',
  'editProduct': 'Editar produto',
  'productName': 'Nome do produto',
  'sku': 'SKU',
  'description': 'Descrição',
  'sellingPrice': 'Preço de venda',
  'costPrice': 'Preço de custo',
  'stockQuantity': 'Quantidade em estoque',
  'lowStockThreshold': 'Limite de estoque baixo',
  'category': 'Categoria',
  'profitMargin': 'Margem de lucro',
  'inStock': 'Em estoque',
  'lowStock': 'Estoque baixo',
  'outOfStock': 'Sem estoque',

  // Orders
  'addOrder': 'Novo pedido',
  'editOrder': 'Editar pedido',
  'orderNumber': 'Pedido nº',
  'customer': 'Cliente',
  'orderItems': 'Itens do pedido',
  'subtotal': 'Subtotal',
  'discount': 'Desconto',
  'deliveryFee': 'Taxa de entrega',
  'tax': 'Imposto',
  'total': 'Total',
  'amountPaid': 'Valor pago',
  'notes': 'Notas',
  'paymentMethod': 'Método de pagamento',
  'deliveryAddress': 'Endereço de entrega',
  'estimatedDelivery': 'Entrega estimada',
  'returnOrder': 'Devolver pedido',

  // Order status
  'pending': 'Pendente',
  'confirmed': 'Confirmado',
  'shipped': 'Enviado',
  'completed': 'Concluído',
  'cancelled': 'Cancelado',

  // Payment status
  'unpaid': 'Não pago',
  'partial': 'Parcial',
  'paid': 'Pago',

  // Payment methods
  'cash': 'Dinheiro',
  'card': 'Cartão',
  'mfs': 'MFS',
  'bank': 'Banco',
  'other': 'Outro',

  // Customers
  'addCustomer': 'Adicionar cliente',
  'editCustomer': 'Editar cliente',
  'customerName': 'Nome',
  'phone': 'Telefone',
  'address': 'Endereço',
  'totalSpent': 'Total gasto',
  'outstandingBalance': 'Saldo pendente',
  'purchaseHistory': 'Histórico de compras (6 meses)',

  // Inventory
  'stockAdjustment': 'Ajuste de estoque',
  'stockMovements': 'Movimentações de estoque',
  'adjustQty': 'Ajustar quantidade',
  'reason': 'Motivo',

  // Expenses
  'addExpense': 'Adicionar despesa',
  'expenseTitle': 'Título da despesa',
  'amount': 'Valor',
  'expenseCategory': 'Categoria',
  'date': 'Data',

  // Settings
  'shopName': 'Nome da loja',
  'currencySymbol': 'Símbolo da moeda',
  'googleAccount': 'Conta Google',
  'backupToDrive': 'Backup no Drive',
  'restoreFromDrive': 'Restaurar do Drive',
  'lastBackup': 'Último backup',
  'appVersion': 'Versão do aplicativo',
  'defaultLowStockThreshold': 'Limite padrão de estoque baixo',
  'clearAllData': 'Limpar todos os dados',
  'signIn': 'Entrar',
  'signOut': 'Sair',
  'taxRate': 'Taxa de imposto (%)',
  'theme': 'Tema',
  'light': 'Claro',
  'dark': 'Escuro',
  'system': 'Sistema',
  'language': 'Idioma',

  // Actions
  'save': 'Salvar',
  'cancel': 'Cancelar',
  'delete': 'Excluir',
  'edit': 'Editar',
  'confirm': 'Confirmar',
  'yes': 'Sim',
  'no': 'Não',
  'add': 'Adicionar',
  'search': 'Pesquisar',
  'filter': 'Filtrar',
  'share': 'Compartilhar',
  'print': 'Imprimir',
  'markAsPaid': 'Marcar como pago',
  'exportCsv': 'Exportar CSV',
  'importCsv': 'Importar CSV',

  // Messages
  'deleteConfirmation': 'Tem certeza de que deseja excluir isso?',
  'clearDataConfirmation':
      'Isso excluirá permanentemente todos os seus dados. Esta ação não pode ser desfeita. Tem certeza?',
  'savedSuccessfully': 'Salvo com sucesso',
  'deletedSuccessfully': 'Excluído com sucesso',
  'errorOccurred': 'Ocorreu um erro. Por favor, tente novamente.',
  'backupSuccess': 'Backup concluído com sucesso',
  'restoreSuccess': 'Dados restaurados com sucesso',
  'noDataFound': 'Nenhum dado encontrado',
  'addFirstProduct': 'Adicione seu primeiro produto para começar',
  'addFirstOrder': 'Nenhum pedido ainda. Crie seu primeiro pedido!',
  'addFirstCustomer': 'Adicione clientes para acompanhar seus pedidos',
  'noExpenses': 'Nenhuma despesa registrada',
  'noStockMovements': 'Nenhuma movimentação de estoque registrada',

  // Reports
  'totalRevenue': 'Receita total',
  'totalProfit': 'Lucro total',
  'totalExpenses': 'Despesas totais',
  'avgOrderValue': 'Valor médio do pedido',
  'topProducts': 'Melhores produtos por receita',
  'topProductsByQty': 'Melhores produtos por quantidade',
  'topCustomers': 'Melhores clientes',
  'salesByCategory': 'Vendas por categoria',

  // Recurring
  'recurringOrder': 'Pedido recorrente',
  'repeatEvery': 'Repetir a cada',
  'days': 'dias',

  // Delivery
  'delivery': 'Entrega',
  'markDelivered': 'Marcar como entregue',
  'delivered': 'Entregue',

  // Variants
  'variants': 'Variantes',
  'addVariant': 'Adicionar variante',
  'variantName': 'Atributo (ex. Tamanho)',
  'variantValue': 'Valor (ex. Grande)',
  'priceAdjustment': 'Preço +/-',
};
